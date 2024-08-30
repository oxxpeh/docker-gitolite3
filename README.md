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
# -- 「--compressed」するような大きさではないですが
docker docker build -t gito3-img --build-arg PASS=rootPass  .
# -- 「rootPass」指定しない場合コンテナのrootパスワードは「PassWord」になります。
# -- proxy必要なら 「--build-arg HTTP_PROXY=http://192.168.1.1:3128」とか

# -- Dockerホストのsshのポートとかぶります。ポート変換するするのもなんなのでmacvlanなるものを使用
# -- すでにmacvlanのネットワーク定義ずみなら飛ばしてください
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

# -- 「docker.io」だけではなく「docker-buildx」もaptでinstall
docker run -d --network macnet --name gito --hostname gito --ip 192.168.1.100  gito3-img
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

macvlanの制限なのか、ホストとコンテナ間の通信は~~なぜか~~できない…   
~~原因などは未調査…~~ 制限らしい(後述)  
  
`docker stop`コマンドでの停止に10秒程度時間がかかります…

<span style="color: #38761d;"><br>(参)<br>立ち上げたDockerが終了するのが遅い<br>https://zenn.dev/mtlom/articles/fb990ddfa6a338</span><br>
>PID1でinit以外のプログラムやSIGTERMを処理しないプログラムがあると、終了しない。
>initのサブプロセスとしてbashを実行していたとしても、SIGTERMを無視するため終了しない。

`docker exec gito kill -s SIGTERM 1`だと即停止するので  
「SIGTERM」を処理してないわけではないようですが…
「run」時に「--init」追加して「docker-init」から「sshd」の起動にしても変わらなかった

## その他
### macvlanの使用
Dockerで既存のブリッジの指定ができなさそう、対策として以下がありそう
1. 「docker network create」で新しくブリッジ作成    
`docker network create -d bridge -o com.docker.network.bridge.name=docker1 docker1`
2. Open vSwitchでブリッジ作成
   「ovs-docker」インストールすれば使えるらしい
3. macvlan  

上の2つは既存のkvmへの変更も伴いそうなので却下  
  
<span style="color: #38761d;"><br>(参)<br>Dockerのネットワークのタイプ - プログラミング初心者がアーキテクトっぽく語る<br>https://architecting.hateblo.jp/entry/2020/08/13/203010</span><br>
>macvlanの制限事項としてホストのEthernetポートとは通信できない。

<span style="color: #38761d;"><br>(参)<br>macvlan ネットワークの使用 — Docker-docs-ja 24.0 ドキュメント<br>https://docs.docker.jp/network/macvlan.html</span><br>
<span style="color: #38761d;"><br>(参)<br>docker network create — Docker-docs-ja 24.0 ドキュメント<br>https://docs.docker.jp/engine/reference/commandline/network_create.html</span><br>
<span style="color: #38761d;"><br>(参)<br>KVMとDockerの両方が入った環境の構築 - メモ - (有)その弐<br>https://sononi.com/memo/2019/06/17/kvmdockercoexist/</span><br>

### 既存データの移行
gitolite3の利用暦
1. ubuntu(ver？)でkvm作成し使い始めて
2. ubuntu(22.10)でデータ移行して
3. 今回ubuntu(24.04)でkvmからDockerに移行

「2.」の時は「/var/lib/gitolite3」のtarをコビーしてファイルのuidとgidを合わせたら動いたと思う  
現在以下となってしまうが「clone」、「commit」など使用可能  
(今回まで気づかなかった…)
```
$ ssh gitolite3@192.168.1.100 -i ~/admin-key 
PTY allocation request failed on channel 0
FATAL: unknown git/gitolite command: 'info'
Connection to 192.168.1.100 closed.
```
今回tarコピーしたら追加で以下でも怒られてgitサーバとして使えない…
```
$ git clone --mirror  ssh://192.168.1.100/testing.git
Cloning into bare repository 'testing.git'...
FATAL: R any testing admin DENIED by fallthru
(or you mis-spelled the reponame)
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```
tarコピーは諦めて各リポジトリでの「--mirror」オプション付けて「clone」と「push」を実施
<span style="color: #38761d;"><br>(参)<br>肥大化したGitリポジトリを別のGitサーバへ移管する｜中央コンピューターサービス株式会社(CCS)<br>https://www.ccs1981.jp/blog/%E8%82%A5%E5%A4%A7%E5%8C%96%E3%81%97%E3%81%9Fgit%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%82%92%E5%88%A5%E3%81%AEgit%E3%82%B5%E3%83%BC%E3%83%90%E3%81%B8%E7%A7%BB%E7%AE%A1%E3%81%99%E3%82%8B/</span><br>
>$ git clone --mirror <移行元URL>
>$ cd <ミラーでできた.gitフォルダ>
>$ git push --mirror <移行先URL>

「clone」と「push」後の物はtarコビーで正常動作  
また`--mount "type=bind,src=/xx/gtl3-data,dst=/home/gitolite3"`追加でホストディレクトリに直接書き込むように

「既存のtarコピー」はubuntuの「18.04」なら動作した  
(22.04と20.4はダメ)  
kvmと比べてDockerだと確認が楽だった

### その他参考サイト
<span style="color: #38761d;"><br>(参)<br>gitolite3をDocker on CentOS7で動かす - Fgken Blog<br>https://ken-2501jp.hatenadiary.org/entry/20141211/1418324691</span><br>
<span style="color: #38761d;"><br>(参)<br>Dockerfile の ARG を使って FROM を変数化する - kakakakakku blog<br>https://kakakakakku.hatenablog.com/entry/2023/03/09/073643</span><br>
<span style="color: #38761d;"><br>(参)<br>Dockerでmacvlanを使う | Reafnex<br>https://reafnex.net/it/it-container/how-to-use-docker-macvlan/</span><br>

## 履歴
2024/08/28  
・コンテナubuntu 24.04で確認
