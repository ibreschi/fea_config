# Service
systemctl list-unit-files --type service -all

systemctl --user list-unit-files


sudo cp ./i3-time_keeper.service /etc/systemd/user/

systemctl --user start i3-time_keeper.service
systemctl --user restart i3-time_keeper.service

systemctl --user status i3-time_keeper.service
