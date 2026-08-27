#!/usr/bin/env bash
#
#  build.sh - Modified for Dhollmen Kernel
#  Clang 17 + arm-gnu-14.2
#

LOCAL_VERSION_NUMBER=xmgm

ARCH=arm64;
THREAD=$(nproc --all);

# ============================================================
# 工具链路径
# ============================================================
TOOLCHAIN_DIR=/home/xm/clgcc
CLANG_PATH=$TOOLCHAIN_DIR/clang17/bin
GCC_PATH=$TOOLCHAIN_DIR/arm-gnu-14.2/bin
GCC_COMPAT_PATH=$TOOLCHAIN_DIR/arm-gnu-14.2/bin

# ============================================================
# 编译工具定义（直接使用完整路径）
# ============================================================
CC=$CLANG_PATH/clang
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=$GCC_PATH/aarch64-none-linux-gnu-
CROSS_COMPILE_COMPAT=$GCC_PATH/aarch64-none-linux-gnu-
CC_ADDITION_FLAGS="OBJDUMP=$CLANG_PATH/llvm-objdump"

# ============================================================
# 输出和打包路径
# ============================================================
KERNEL_ROOT=$(pwd)
OUT="$KERNEL_ROOT/out";
BUILD_OUTPUT_DIR=/home/xm

TARGET_KERNEL_FILE=arch/arm64/boot/Image;
TARGET_KERNEL_DTB=arch/arm64/boot/dtb;
TARGET_KERNEL_DTBO=arch/arm64/boot/dtbo.img
TARGET_KERNEL_NAME=Kernel;
TARGET_KERNEL_MOD_VERSION=$(make kernelversion)-$LOCAL_VERSION_NUMBER;

DEFCONFIG_PATH=arch/arm64/configs
DEFCONFIG_NAME=vendor/gauguin_user_defconfig;

START_SEC=$(date +%s);
CURRENT_TIME=$(date '+%Z-%Y-%m-%d-%H%M');

# ============================================================
# AnyKernel3 下载到 /home/xm
# ============================================================
ANYKERNEL_URL=https://codeload.github.com/Molyuu/AnyKernel3/zip/refs/heads/main;
ANYKERNEL_DIR=/home/xm/AnyKernel3-main;
ANYKERNEL_FILE=/home/xm/anykernel.zip;

# ============================================================
# 检查工具链是否存在
# ============================================================
check_toolchain(){
    echo "------------------------------";
    echo " Checking toolchain...";
    echo "------------------------------";

    if [ ! -d "$TOOLCHAIN_DIR/clang17" ]; then
        echo "ERROR: clang17 not found at $TOOLCHAIN_DIR/clang17"
        echo "Please download it first"
        exit 1
    fi

    if [ ! -f "$CLANG_PATH/clang" ]; then
        echo "ERROR: clang binary not found at $CLANG_PATH/clang"
        exit 1
    fi

    if [ ! -d "$TOOLCHAIN_DIR/arm-gnu-14.2" ]; then
        echo "ERROR: arm-gnu-14.2 not found at $TOOLCHAIN_DIR/arm-gnu-14.2"
        echo "Please download it first"
        exit 1
    fi

    if [ ! -f "$GCC_PATH/aarch64-none-linux-gnu-gcc" ]; then
        echo "ERROR: aarch64-none-linux-gnu-gcc not found at $GCC_PATH/"
        exit 1
    fi

    echo "Toolchain OK:"
    echo "  Clang: $CLANG_PATH"
    echo "  GCC:   $GCC_PATH"
}

# ============================================================
# 链接 dtb
# ============================================================
link_all_dtb_files(){
    if [ -d "$OUT/arch/arm64/boot/dts/vendor/qcom" ]; then
        find $OUT/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > $OUT/arch/arm64/boot/dtb;
    else
        echo "Warning: dtb directory not found, creating empty dtb"
        touch $OUT/arch/arm64/boot/dtb
    fi
}

# ============================================================
# defconfig
# ============================================================
make_defconfig(){
    echo "------------------------------";
    echo " Building Kernel Defconfig..";
    echo "------------------------------";

    make CC=$CC ARCH=$ARCH \
         CROSS_COMPILE=$CROSS_COMPILE \
         CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
         CLANG_TRIPLE=$CLANG_TRIPLE \
         O=$OUT -j$THREAD $DEFCONFIG_NAME;
}

# ============================================================
# 编译内核
# ============================================================
build_kernel(){
    echo "------------------------------";
    echo " Building Kernel ...........";
    echo "------------------------------";
    
    rm -rf $OUT/AnyKernel3-main;
    make CC=$CC ARCH=$ARCH \
         CROSS_COMPILE=$CROSS_COMPILE \
         CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
         CLANG_TRIPLE=$CLANG_TRIPLE \
         $CC_ADDITION_FLAGS \
         O=$OUT -j$THREAD;

    END_SEC=$(date +%s);
    COST_SEC=$[ $END_SEC-$START_SEC ];
    echo "Kernel Build Costed $(($COST_SEC/60))min $(($COST_SEC%60))s"
}

# ============================================================
# menuconfig
# ============================================================
menuconfig_edit(){
    echo "------------------------------";
    echo " Launching menuconfig";
    echo "------------------------------";

    make CC=$CC ARCH=$ARCH \
         CROSS_COMPILE=$CROSS_COMPILE \
         CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
         CLANG_TRIPLE=$CLANG_TRIPLE \
         O=$OUT menuconfig;

    echo "Saving defconfig..."
    make CC=$CC ARCH=$ARCH \
         CROSS_COMPILE=$CROSS_COMPILE \
         CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
         CLANG_TRIPLE=$CLANG_TRIPLE \
         O=$OUT savedefconfig;

    cp $OUT/defconfig $DEFCONFIG_PATH/$DEFCONFIG_NAME
    echo "Defconfig saved to $DEFCONFIG_PATH/$DEFCONFIG_NAME"
}

# ============================================================
# 生成刷机包
# ============================================================
generate_flashable(){
    echo "------------------------------";
    echo " Generating Flashable Kernel";
    echo "------------------------------";

    cd $OUT;
    
    echo "Getting AnyKernel3..."
    curl -L $ANYKERNEL_URL -o $ANYKERNEL_FILE;

    unzip -o $ANYKERNEL_FILE -d /home/xm/;

    echo "Removing old package file...";
    rm -rf $ANYKERNEL_DIR/Kernel-*;

    echo "Copying Kernel File..."; 
    cp -r $TARGET_KERNEL_FILE $ANYKERNEL_DIR/;
    
    if [ -f "$TARGET_KERNEL_DTB" ]; then
        cp -r $TARGET_KERNEL_DTB $ANYKERNEL_DIR/;
    fi
    
    if [ -f "$TARGET_KERNEL_DTBO" ]; then
        cp -r $TARGET_KERNEL_DTBO $ANYKERNEL_DIR/;
    fi

    # 修改 anykernel.sh 跳过设备检查
    if [ -f "$ANYKERNEL_DIR/anykernel.sh" ]; then
        sed -i 's/do.devicecheck=1/do.devicecheck=0/g' $ANYKERNEL_DIR/anykernel.sh 2>/dev/null || true
        if ! grep -q "do.devicecheck" $ANYKERNEL_DIR/anykernel.sh; then
            sed -i '/properties() {/a\do.devicecheck=0' $ANYKERNEL_DIR/anykernel.sh
        fi
    fi

    echo "Packaging flashable Kernel...";
    cd $ANYKERNEL_DIR;
    zip -q -r $BUILD_OUTPUT_DIR/$TARGET_KERNEL_NAME-$CURRENT_TIME-$TARGET_KERNEL_MOD_VERSION.zip *;

    echo "Target File: $BUILD_OUTPUT_DIR/$TARGET_KERNEL_NAME-$CURRENT_TIME-$TARGET_KERNEL_MOD_VERSION.zip";
}

# ============================================================
# 保存 defconfig
# ============================================================
save_defconfig(){
    echo "------------------------------";
    echo " Saving kernel config ........";
    echo "------------------------------";

    make CC=$CC ARCH=$ARCH \
         CROSS_COMPILE=$CROSS_COMPILE \
         CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
         CLANG_TRIPLE=$CLANG_TRIPLE \
         $CC_ADDITION_FLAGS \
         O=$OUT -j$THREAD savedefconfig;

    END_SEC=$(date +%s);
    COST_SEC=$[ $END_SEC-$START_SEC ];
    echo "Finished. Kernel config saved to $OUT/defconfig"
    echo "Moving kernel defconfig to source tree"
    mv $OUT/defconfig $DEFCONFIG_PATH/$DEFCONFIG_NAME
    echo "Kernel Config Build Costed $(($COST_SEC/60))min $(($COST_SEC%60))s"
}

# ============================================================
# 清理
# ============================================================
clean(){
    echo "Clean source tree and build files..."
    make mrproper -j$THREAD;
    make clean -j$THREAD;
    rm -rf $OUT;
}

# ============================================================
# 菜单
# ============================================================
main(){
    case "${1:-}" in
        help|-h)
            echo "build.sh: Kernel build helper"
            echo "usage: build.sh <build option>"
            echo
            echo "Build options:"
            echo "    all             Perform a build without cleaning."
            echo "    cleanbuild      Clean then build."
            echo "    menuconfig      Open menuconfig, then save defconfig."
            echo "    flashable       Only generate flashable zip."
            echo "    savedefconfig   Save defconfig to source tree."
            echo "    defconfig       Only build defconfig."
            echo "    version         Display version."
            echo
            echo "Toolchain:"
            echo "  Clang: $TOOLCHAIN_DIR/clang17"
            echo "  GCC:   $TOOLCHAIN_DIR/arm-gnu-14.2"
            ;;
        savedefconfig)
            check_toolchain
            save_defconfig
            ;;
        cleanbuild)
            check_toolchain
            clean
            make_defconfig
            build_kernel
            link_all_dtb_files
            generate_flashable
            ;;
        flashable)
            generate_flashable
            ;;
        kernelonly)
            check_toolchain
            make_defconfig
            build_kernel
            ;;
        all)
            check_toolchain
            make_defconfig
            build_kernel
            link_all_dtb_files
            generate_flashable
            ;;
        menuconfig)
            check_toolchain
            make_defconfig
            menuconfig_edit
            ;;
        defconfig)
            check_toolchain
            make_defconfig
            ;;
        version)
            echo "Current version is: $LOCAL_VERSION_NUMBER"
            ;;
        *)
            echo "Incorrect usage. Run: bash build.sh help"
            ;;
    esac
}

main "$1"
