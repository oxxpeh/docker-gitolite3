# gitolite3が動作するDockerファイル
kvmで動作しているものをDockerに移すときに使用したので
## 使い方
```
mkdir gito3 && cd gito3
# -- 「gito3」でなくても何でも良いです
copy /XX/XX/admin.pub .
# -- gitolite3の管理者アカウントとして利用するユーザの公開鍵をコビー
# -- パスは適当なものに、Dockerファイルで指定しているので、名前は「admin.pub」で
# -- 鍵の作り方は省略…
curl --compressed -O https://raw.githubusercontent.com/oxxpeh/docker-gitolite3/main/Dockerfile
docker docker build -t gito3 --build-arg PASS=rootPass  .
# -- 「rootPass」指定しない場合コンテナのrootパスワードは「PassWord」になります。
# -- proxy必要なら 「--build-arg HTTP_PROXY=http://192.168.1.1:3128」とか

# -- Dockerホストのsshのポートとかぶります。ポート変換するするのもなんなのでmacvlanなるものを使用
# -- すでにmacvlanのネットワーク定義ずみなら飛ばしいてください
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --ip-range=192.168.1.240/28 \
  --gateway=192.168.1.1 \
  -o parent=br0 macnet
# -- 「ip-range」アドレス指定しない場合に使用されるアドレスと思います。
# -- (run 時に固定設定予定)
# -- 「parent=br0」 kvmでbridge使用してたので物理NICでなくてbr0にしてますが
# -- 使用してない場合は物理NIC(enpxx)とかに変えてください
# -- 最後の「macnet」はネットワーク名になります。

# -- 「docker.io」だけではなく「docker-buildx」もaptでinstallしておく
docker run -d --network macnet --name gito --hostname gito --ip 192.168.1.100  gito3
# -- クライアントから確認
ssh gitolite3@192.168.1.100 -i admin-key
# -- 以下サーバの表示
# PTY allocation request failed on channel 0                                                
# hello admin, this is gitolite3@gito24 running gitolite3 3.6.12-1 (Debian) on git 2.43.0
#                                                                                           
#  R W    gitolite-admin                                                                    
#  R W    testing                                                                           
# Connection to 192.168.1.100 closed.
```

macvlanの制限なのか、ホストとコンテナ間の通信はなぜかできませんでした…   
原因などは未調査…                                                       
## その他
既存データの移行とか記載予定
## 履歴
工事中
