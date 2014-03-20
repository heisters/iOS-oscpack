#!/bin/bash

tshark -f 'udp port 5555' -T text
