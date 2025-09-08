
          if [ -n "$ANDROID_NDK" ]; then
              export NDK=${ANDROID_NDK}
          elif [ -n "$ANDROID_NDK_HOME" ]; then
              export NDK=${ANDROID_NDK_HOME}
          else
              export NDK=~/android-ndk-r28c
          fi
          
          if [ ! -d "$NDK" ]; then
              echo "Please set ANDROID_NDK environment to the root of NDK."
              exit 1
          fi
          
          function build() {
              API=$1
              ABI=$2
              TOOLCHAIN_NAME=$3
              BUILD_PATH=build.Android.${ABI}
              
              echo "Building $ABI with 16KB alignment..."
              
              # 设置16KB对齐的编译标志
              export CFLAGS="-fmax-page-size=16384"
              export CXXFLAGS="-fmax-page-size=16384"
              export LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
              
              # 对于arm64-v8a，添加额外的对齐标志
              if [ "$ABI" = "arm64-v8a" ]; then
                  export CFLAGS="$CFLAGS -falign-functions=16384"
                  export CXXFLAGS="$CXXFLAGS -falign-functions=16384"
                  export LDFLAGS="$LDFLAGS -Wl,--section-alignment=16384"
              fi
              
              cmake -H. -B${BUILD_PATH} \
                  -DANDROID_ABI=${ABI} \
                  -DCMAKE_BUILD_TYPE=Release \
                  -DCMAKE_TOOLCHAIN_FILE=${NDK}/build/cmake/android.toolchain.cmake \
                  -DANDROID_NATIVE_API_LEVEL=${API} \
                  -DANDROID_TOOLCHAIN=clang \
                  -DANDROID_TOOLCHAIN_NAME=${TOOLCHAIN_NAME} \
                  -DCMAKE_C_FLAGS="$CFLAGS" \
                  -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
                  -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
                  -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS"
              
              cmake --build ${BUILD_PATH} --config Release
              
              mkdir -p plugin_lua53/Plugins/Android/libs/${ABI}/
              cp ${BUILD_PATH}/libxlua.so plugin_lua53/Plugins/Android/libs/${ABI}/libxlua.so
              
              # 验证16KB对齐
              echo "Verifying 16KB alignment for $ABI:"
              readelf -l ${BUILD_PATH}/libxlua.so | grep -A 1 "LOAD" || echo "No LOAD segments found"
              readelf -S ${BUILD_PATH}/libxlua.so | grep -E "\.(text|data|rodata)" || echo "No sections found"
          }
          
          build android-35 armeabi-v7a arm-linux-androideabi-4.9
          build android-35 arm64-v8a arm-linux-androideabi-clang
          build android-35 x86 x86-4.9