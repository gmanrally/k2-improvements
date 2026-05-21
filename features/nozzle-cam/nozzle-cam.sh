#!/bin/sh
# Toggle the K2 Plus nozzle camera and an MJPEG HTTP stream.
#
# Usage:
#   nozzle-cam.sh on       Power cam, kill stock cam_sub_app, start ffmpeg HTTP stream.
#   nozzle-cam.sh off      Stop ffmpeg, power cam off.
#   nozzle-cam.sh status   Print ON/OFF and PID.

set -e

PORT=8081
WIDTH=1280
HEIGHT=720
FPS=5
DEV=/dev/video2
PIDFILE=/var/run/nozzle-cam-ffmpeg.pid
LOG=/tmp/nozzle-cam-ffmpeg.log
POWER=/usr/bin/nozzle_cam_power.sh
FFMPEG=/opt/bin/ffmpeg

[ -f /etc/profile.d/entware.sh ] && . /etc/profile.d/entware.sh

stop_stream() {
    if [ -f "$PIDFILE" ]; then
        kill -9 "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi
    killall ffmpeg 2>/dev/null || true
    killall cam_sub_app 2>/dev/null || true
    rm -f /var/run/sub-video*.pid
}

case "$1" in
    on)
        stop_stream
        "$POWER" on
        # Wait up to 12s for /dev/video2 to appear via USB enumeration.
        i=0
        while [ ! -e "$DEV" ] && [ $i -lt 12 ]; do
            sleep 1
            i=$((i + 1))
        done
        if [ ! -e "$DEV" ]; then
            echo "ERROR: $DEV did not appear within 12s; powering off"
            "$POWER" off
            exit 1
        fi
        # The udev hotplug for the new /dev/video2 fires auto_uvc.sh, which spawns
        # cam_sub_app and grabs the device. Wait for it to actually start, then kill it.
        # Retry the whole open up to 3 times in case it respawns.
        attempt=0
        while [ $attempt -lt 3 ]; do
            sleep 3
            killall cam_sub_app 2>/dev/null || true
            rm -f /var/run/sub-video*.pid
            sleep 1
            "$FFMPEG" -nostdin -hide_banner -loglevel warning \
                -f v4l2 -input_format mjpeg -video_size ${WIDTH}x${HEIGHT} -framerate $FPS \
                -i "$DEV" \
                -c:v copy -f mpjpeg \
                -content_type "multipart/x-mixed-replace;boundary=ffmpeg" \
                -listen 1 "http://0.0.0.0:$PORT" \
                > "$LOG" 2>&1 &
            FFPID=$!
            sleep 2
            if kill -0 $FFPID 2>/dev/null; then
                echo $FFPID > "$PIDFILE"
                echo "ON pid=$FFPID url=http://$(hostname -i 2>/dev/null | awk '{print $1}'):$PORT/"
                exit 0
            fi
            attempt=$((attempt + 1))
            echo "ffmpeg attempt $attempt failed, retrying..."
        done
        echo "ERROR: ffmpeg could not open $DEV after 3 attempts"
        cat "$LOG" 2>/dev/null | tail -5
        "$POWER" off
        exit 1
        ;;
    off)
        stop_stream
        "$POWER" off
        echo "OFF"
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "ON pid=$(cat "$PIDFILE") port=$PORT"
        else
            echo "OFF"
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        exit 2
        ;;
esac
