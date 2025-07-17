wget https://musl.cc/mips64el-linux-musl-cross.tgz
mkdir toolchains
tar -xzf mips64el-linux-musl-cross.tgz -C toolchains
rm mips64el-linux-musl-cross.tgz
# fix include path link
rmdir toolchains/mips64el-linux-musl-cross/include
ln -s $PWD/toolchains/mips64el-linux-musl-cross/mips64el-linux-musl/include $PWD/toolchains/mips64el-linux-musl-cross/include
