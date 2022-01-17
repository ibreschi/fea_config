#!/usr/bin/env python3

import os
import csv
from tempfile import NamedTemporaryFile
import shutil
import time
import threading

from datetime import date

from contextlib import contextmanager
from i3ipc import Connection, Event


class Clock:
    """
    Class that knows how to keep time
    """
    def __init__(self):
        self.elapsed_time = 0

    def start(self):
        self.start_time = time.time()

    def stop(self):
        self.elapsed_time = time.time() - self.start_time

    def get_elapsed_time(self):
        return self.elapsed_time


class ReadWrtier:
    FIELDS = ['date', 'work', 'personal', 'elses']

    def __init__(self, file_name):
        self.file_name = file_name
        if not os.path.isfile(self.file_name):
            self.write_header_csv()

    def write_header_csv(self):
        with open(self.file_name, mode='w') as time_logs_file:
            writer = csv.DictWriter(time_logs_file, fieldnames=self.FIELDS)
            writer.writeheader()

    def readline_csv(self):
        with open(self.file_name, mode='r') as time_logs_file:
            final_line = time_logs_file.readlines()[-1]
            return final_line

    def appendline_csv(self, date, work, personal, elses):
        with open(self.file_name, mode='a') as time_logs_file:
            time_logs_writer = csv.writer(time_logs_file, delimiter=',')
            time_logs_writer.writerow([date, work, personal, elses])

    def updateline_csv(self, date, work, personal, elses):
        tempfile = NamedTemporaryFile(mode='w', delete=False)
        with open(self.file_name, 'r') as csvfile, tempfile:
            reader = csv.DictReader(csvfile, fieldnames=self.FIELDS)
            writer = csv.DictWriter(tempfile, fieldnames=self.FIELDS)
            for row in reader:
                if row['date'] == date:
                    row['date'], row['work'], row['personal'], row['elses'] = date, work, personal, elses
                    print(row)
                row = {'date': row['date'], 'work': row['work'], 'personal': row['personal'], 'elses': row['elses']}
                writer.writerow(row)

        shutil.move(tempfile.name, self.file_name)


class Controller:

    WORK_WORKSPACES = ['1', '2', '3', '5']
    PERSO_WORKSPACES = ['4']

    def __init__(self):
        self.rw = ReadWrtier('/home/ibreschi/.i3_time_keeper')
        self.set_today()

        # Should this two object be tread safe?
        self.time_pools = self._take_today_entry()
        self.clocks = {}
        self.prev_workspace = None

        self.lock = threading.Lock()

    def set_today(self):
        today = date.today()
        self.today_date = today.strftime("%d/%m/%Y")

    def _take_today_entry(self):
        '''
        If today entry exists return it, otherwise write one empty to the file and return it
        '''
        line = self.rw.readline_csv()
        parts = line.split(',')
        if parts[0] == self.today_date:
            # Today entry was found. We are probably restarting the program
            return {'Work': int(parts[1]), 'Personal': int(parts[2]), 'Elses': int(parts[3])}
        else:
            # Today entry was not found. It's the first time in the day we log the time
            self.rw.appendline_csv(self.today_date, 0, 0, 0)
            return {'Work': 0, 'Personal': 0, 'Elses': 0}

    def has_clock(self, name):
        return name in self.clocks

    def add_clock(self, name, value):
        self.clocks[name] = value

    def get_clock(self, name):
        return self.clocks[name]

    def add_to_time_pool(self, name, duration):
        with self.lock:
            if name not in self.time_pools:
                self.time_pools[name] = 0
            self.time_pools[name] += duration

    def track(self, name, duration):
        if name in self.WORK_WORKSPACES:
            self.add_to_time_pool('Work', duration)
        elif name in self.PERSO_WORKSPACES:
            self.add_to_time_pool('Personal', duration)
        else:
            self.add_to_time_pool('Elses', duration)

    def print_stats(self):
        for k, v in self.time_pools.items():
            print("On {} passed {}".format(k, v))

    def update_entries(self):
        """
        Log today time.
        """
        work_time = int(self.time_pools['Work'])
        perso_time = int(self.time_pools['Personal'])
        elses_time = int(self.time_pools['Elses'])
        self.rw.updateline_csv(self.today_date, work_time, perso_time, elses_time)

        today = date.today()
        new_today_date = today.strftime("%d/%m/%Y")
        if new_today_date != self.today_date:
            # we passed the midnight
            self.rw.appendline_csv(new_today_date, 0, 0, 0)
            self.set_today()

    def do_logic(self, workspace_name):
        if not self.prev_workspace:
            # First time:
            clock = Clock()
            clock.start()
            self.add_clock(workspace_name, clock)
        else:
            # Other times:
            # We changed workspace so we stop the clock in wich we were previouslly
            clock = self.get_clock(self.prev_workspace)
            clock.stop()
            elapsed_time = clock.get_elapsed_time()
            print(workspace_name, elapsed_time)
            self.track(self.prev_workspace, elapsed_time)

            if not self.has_clock(workspace_name):
                clock = Clock()
                self.add_clock(workspace_name, clock)

            clock = self.get_clock(workspace_name)
            clock.start()
        self.prev_workspace = workspace_name


@contextmanager
def track_my_time():
    c = Controller()
    try:
        yield c
    finally:
        c.update_entries()


class FocusWatcher:

    def __init__(self, controller):
        self.controller = controller

        self.tick_time = 3
        self.i3 = Connection()
        self.i3.on(Event.WORKSPACE_FOCUS, self.on_workspace_focus)
        self.i3.on(Event.SHUTDOWN, self.on_exit)

    def run(self):
        t_i3 = threading.Thread(target=self._launch_i3)
        t_server = threading.Thread(target=self._launch_server)
        for t in (t_i3, t_server):
            t.start()

    def on_workspace_focus(self, i3conn, e):
        # The first parameter is the connection to the ipc and the second is an object
        # with the data of the event sent from i3.
        if e.current:
            self.controller.do_logic(e.current.name)

    def on_exit(self, i3conn, e):
        self.controller.update_entries()

    def _launch_i3(self):
        self.i3.main()

    def _launch_server(self):
        while True:
            time.sleep(self.tick_time)
            self.controller.update_entries()


with track_my_time() as controller:
    focus_watcher = FocusWatcher(controller)
    focus_watcher.run()
