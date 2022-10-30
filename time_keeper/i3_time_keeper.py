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


class RepeatedTimer(object):
    def __init__(self, interval, function, *args, **kwargs):
        self._timer = None
        self.interval = interval
        self.function = function
        self.args = args
        self.kwargs = kwargs
        self.is_running = False
        self.next_call = time.time()
        self.start()

    def _run(self):
        self.is_running = False
        self.start()
        self.function(*self.args, **self.kwargs)

    def start(self):
        if not self.is_running:
            self.next_call += self.interval
            self._timer = threading.Timer(self.next_call - time.time(), self._run)
            self._timer.start()
            self.is_running = True

    def stop(self):
        self._timer.cancel()
        self.is_running = False


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

    def __init__(self, config_file):
        self.rw = ReadWrtier(config_file)
        self.set_today()

        # Time pools is written by one thread and read by one other. It should be locked
        self.time_pools = self._take_today_entry()
        self.clocks = {}
        self.prev_workspace = None

        self.lock = threading.Lock()

    def init(self):
        print('Welcome in WorkTracker')

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

    def start_clock(self, name):
        if name not in self.clocks:
            # To init the clocks in case we do not have them
            self.clocks[name] = Clock()
        self.clocks[name].start()

    def stop_clock(self, name):
        self.clocks[name].stop()
        return self.clocks[name].get_elapsed_time()

    def track(self, name, duration):
        with self.lock:
            if name in self.WORK_WORKSPACES:
                self.time_pools['Work'] += duration
            elif name in self.PERSO_WORKSPACES:
                self.time_pools['Personal'] += duration
            else:
                self.time_pools['Elses'] += duration

    def get_times(self):
        with self.lock:
            work = int(self.time_pools['Work'])
            perso = int(self.time_pools['Personal'])
            elses = int(self.time_pools['Elses'])
        return work, perso, elses

    def write_record(self):
        """
        Write to file log time.
        """

        work, perso, elses = self.get_times()
        self.rw.updateline_csv(self.today_date, work, perso, elses)

        today = date.today()
        new_today_date = today.strftime("%d/%m/%Y")
        if new_today_date != self.today_date:
            # we passed the midnight
            self.rw.appendline_csv(new_today_date, 0, 0, 0)
            self.set_today()

    def track_time(self, workspace_name):
        """
        Measure time passed in workspaces.
        """
        if self.prev_workspace:
            # We changed workspace so we stop the clock in wich we were previouslly
            elapsed_time = self.stop_clock(self.prev_workspace)
            print("Passed", elapsed_time, 'in workspace:', self.prev_workspace)
            self.track(self.prev_workspace, elapsed_time)

        # We now start one
        print("Starting new timer for workspace:", workspace_name)
        self.start_clock(workspace_name)
        self.prev_workspace = workspace_name


@contextmanager
def track_my_time():
    c = Controller('/home/ibreschi/.i3_time_keeper', )
    try:
        yield c
    finally:
        c.write_record()


class FocusWatcher:
    def __init__(self, controller):
        self.controller = controller

        self.i3 = Connection()
        self.i3.on(Event.WORKSPACE_FOCUS, self.on_workspace_focus)
        self.i3.on(Event.TICK, self.on_tick)
        self.i3.on(Event.SHUTDOWN, self.controller.write_record)
        self.rt = RepeatedTimer(3, self.i3.send_tick)
        self.i3.main()

    def on_workspace_focus(self, i3conn, e):
        if e.current:
            self.controller.track_time(e.current.name)

    def on_tick(self, i3conn, e):
        if e.first:
            # We do not write_record as it will be done already by on_workspace_focus
            self.controller.init()
        else:
            self.controller.write_record()


with track_my_time() as controller:
    FocusWatcher(controller)
