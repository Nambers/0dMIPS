wget https://musl.cc/mips64el-linux-musl-cross.tgz
mkdir toolchains
tar -xzf mips64el-linux-musl-cross.tgz -C toolchains
rm mips64el-linux-musl-cross.tgz
# fix include path link
rm toolchains/mips64el-linux-musl-cross/include
ln -s toolchains/mips64el-linux-musl-cross/mips64el-linux-musl/include toolchains/mips64el-linux-musl-cross/include
