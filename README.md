# Live Stream Recorder

一系列简陋的 Bash 脚本，可以实现 YouTube、Twitch、TwitCasting 等平台主播开播时自动录像。

因为我喜欢的 VTuber [神楽めあ](https://twitter.com/freeze_mea) 是个喜欢突击直播还不留档的惯犯，所以我写了这些脚本挂在 VPS 上监视直播动态，一开播就自动开始录像，这样就算错过了直播也不用担心。

脚本的工作原理很简单，就是每过 30s 检查一次直播状态（这个延迟可以在脚本中的 `sleep 30` 处调节），如果在播就开始录像，没在播就继续轮询，非常简单粗暴（因为我懒得用 PubSubHubbub，而且我这台 VPS 就是专门为了录 mea 买的，所以不用在意性能之类的问题）。

这些脚本支持的直播平台基本上覆盖了 mea 的活动范围，如果有其他希望支持的平台也可以开 issue。

## 前置依赖

本脚本依赖以下程序，请自行安装并保证能在 `$PATH` 中找到。

- ffmpeg
- youtube-dl
- streamlink

需要注意的是，各大 Linux 发行版官方软件源中的 ffmpeg 版本可能过旧（3.x 甚至 2.x），录像时会出现奇怪的问题，推荐在 [这里](https://johnvansickle.com/ffmpeg/) 下载最新版本（4.x）的预编译二进制文件。

youtube-dl 和 streamlink 都可以直接使用 pip 进行安装。

## YouTube 自动录像

```
./record_youtube.sh "https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw/live"
```

参数为 YouTube 频道待机室的 URL（即在频道 URL 后面添加 `/live`），这样可以实现无人值守监视开播。参数也可以是某次直播的直播页面 URL（`./record_youtube.sh "https://www.youtube.com/watch?v=9KbIgi3qEb4"`），不过这样就只能对这一场直播进行录像，录不到该频道的后续直播，所以推荐使用前者。如果频道主关闭了非直播时间的 `/live` 待机室也没关系，脚本也对此情况进行了适配。

录像文件默认保存在脚本文件所在的目录下，文件名格式为 `youtube_{id}_YYMMDD_HHMMSS_{title}.ts`，比如 `youtube_vFfIDm35SbA_20181021_203125_反省会.ts`。输出的视频文件使用 MPEG-2 TS 容器格式保存，因为 TS 格式有着可以从任意位置开始解码的优势，就算录像过程中因为网络波动等问题造成了中断，也不至于损坏整个视频文件。如果需要转换为 MP4 格式，可以使用以下命令：

```
ffmpeg -i xxx.ts -codec copy xxx.mp4
```

## Twitch 自动录像

```
./record_twitch.sh kagura0mea
```

参数为 Twitch 用户名，就是直播页面 URL 中 `twitch.tv` 后面的那个。

录像的文件名格式为 `twitch_{id}_YYMMDD_HHMMSS.ts`，其他与上面的相同。

## TwitCasting 自动录像

```
./record_twitcast.sh kaguramea
```

参数为 TwitCasting 用户名，就是直播页面 URL 中 `twitcasting.tv` 后面的那个。

录像的文件名格式为 `twitcast_{id}_YYMMDD_HHMMSS.ts`，其他与上面的相同。

## 后台运行脚本

如果用上面那些方式运行脚本，终端退出后脚本就会停止，所以你需要使用 `nohup` 命令将脚本放到后台中运行：

```
nohup ./record_youtube.sh "https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw/live" > mea.log &
```

这会把脚本的输出写入至日志文件 `mea.log`（文件名自己修改），你可以随时使用 `tail -f mea.log` 命令查看实时日志。

其他脚本同理：

```
nohup ./record_twitch.sh kagura0mea > mea_twitch.log &
nohup ./record_twitcast.sh kaguramea > mea_twitcast.log &
```

使用命令 `ps -ef | grep record` 可以列出当前正在后台运行的录像脚本，其中第一个数字即为脚本进程的 PID：

```
root      1166     1  0 13:21 ?        00:00:00 /bin/bash ./record_youtube.sh ...
root      1558     1  0 13:25 ?        00:00:00 /bin/bash ./record_twitcast.sh ...
root      1751     1  0 13:27 ?        00:00:00 /bin/bash ./record_twitch.sh ...
```

如果需要终止正在后台运行的脚本，可以使用命令 `kill {pid}`（比如要终止上面的第一个 YouTube 录像脚本，运行 `kill 1166` 即可）。

## 已知问题

YouTube 录像脚本中，youtube-dl 调起的 ffmpeg 进程有时候在直播结束后还会继续运行，一直持续很长时间才自动退出（几十分钟到几小时不等，表现为日志文件中不断出现的 `Last message repeated xxx times`），原因不明，似乎是 youtube-dl 的一个 [BUG](https://github.com/rg3/youtube-dl/issues/12271)。如果 ffmpeg 进程一直不退出就会造成阻塞，导致在这段时间内新开的直播无法录像，所以推荐在看到 YouTube 下播后手动终止一下可能挂起的 ffmpeg 进程。

首先运行 `ps -ef | grep youtube-dl` 获取 `youtube-dl` 进程的 PID：

```
root     26614  1166 29 20:31 ?        00:00:00 /usr/bin/python /usr/local/bin/youtube-dl --no-playlist --playlist-items 1 --match-filter is_live --hls-use-mpegts -o youtube_%(id)s_20181021_203125_%(title)s.ts https://www.youtube.com/channel/UCWCc8tO-uUl_7SJXIKJACMw/live
```

然后使用以下命令向 youtube-dl 进程发送 `SIGINT` 信号终止程序：

```
kill -s INT 26614
```

为什么是向 youtube-dl 而非 ffmpeg 进程发送信号？因为 youtube-dl 在 ffmpeg 进程正常退出之后还需要进行一些操作（比如对 `.part` 文件进行处理），而如果直接向 ffmpeg 进程发送 `SIGINT` 信号会让 youtube-dl 以为 ffmpeg 进程异常退出（而非接受用户的中断指令退出），就不会进行那些后续处理。发送 `SIGINT` 信号而非其他信号也是为了让它可以执行这些操作。

如果是其他平台的录像脚本，那直接向 ffmpeg 进程发送 `SIGINT` 信号就可以了。

## 开源许可

MIT License (c) 2018 printempw