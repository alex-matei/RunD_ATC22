#! /bin/bash
DIR=$(dirname $0)
kata_config="/etc/kata-containers/configuration-fc.toml"
containerd_config="/etc/containerd/config.toml"
crictl_config="/etc/crictl.yaml"
source $DIR/mem_test.conf

sed -r -i "s/snapshotter = \".*\"/snapshotter = \"devmapper\"/g" ${containerd_config}
systemctl restart containerd
sleep 10

start_date=$(date +%m%d%H%M)
base_dir=$(printf "mem_katafc_%s" $start_date)
mkdir -p ${base_dir}
version="${base_dir}/versions.txt"
uname -r >> $version
containerd --version >> $version
crictl --version >> $version
kata-runtime --version >> $version
firecracker --version >> $version
cp $kata_config $base_dir/
cp $containerd_config $base_dir/
cp $crictl_config $base_dir/

export ns="mem-test"
for mem in ${memory[@]}; do
    sed -r -i "s/default_memory = [0-9]+/default_memory = $(($mem + 160))/g" $kata_config
    for c in ${density[@]}; do
        echo "--- kata-fc ${mem}MB $c"
        result_fn=$(printf "%s/result_%sMB_%04d.txt" $base_dir $mem $c)
        $DIR/gen_container.sh $c kata-fc
        $DIR/smem_result.sh "^((/firecracker)|(/opt/kata/))" > $result_fn
    done
    $DIR/clean.sh $ns
done

sed -r -i "s/snapshotter = \".*\"/snapshotter = \"overlayfs\"/g" ${containerd_config}
systemctl restart containerd