#!/bin/bash

# Copyright (c) 2023  Thilo Fischer.
# Free software licensed under GPL v3. See LICENSE.txt for details.

date >> context.log
ip address >> context.log
ip route >> context.log

ip -ts monitor all label 2>&1 | tee -a ip-monitor.log &

./inetconlog.rb 2>&1 | tee -a inetconlog.log

