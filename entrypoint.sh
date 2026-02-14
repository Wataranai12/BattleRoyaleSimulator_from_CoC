#!/bin/bash
set -e

# Rails 特有の問題（server.pid が残っていると起動できない）を解決するための処理
rm -f /myapp/tmp/pids/server.pid

# コンテナのメインプロセス（Dockerfile の CMD で指定されたもの）を実行
exec "$@"