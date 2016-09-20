//
//  SNTrimVertical.metal
//  SNTrim
//
//  Created by satoshi on 9/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Pixel {
    uint rgba;
};

kernel void SNTrimVertical(const device Pixel* pixelBuffer [[ buffer(0) ]],
                      const device ushort& width [[ buffer(1) ]],
                      const device ushort& height [[ buffer(2) ]],
                      device Pixel* outputBuffer [[ buffer(3) ]],

                      const uint tgPos [[ threadgroup_position_in_grid ]],
                      const uint tPerTg [[ threads_per_threadgroup ]],
                      const uint tPos [[ thread_position_in_threadgroup ]]) {
    
    uint offset = tgPos * tPerTg + tPos;
    if (offset >= width) {
        return;
    }
    
    const device Pixel* lineBuffer = pixelBuffer + offset;
    uint result = 0;
    for(ushort index=0; index < height; index++) {
        result |= lineBuffer[index * width].rgba;
    }
    outputBuffer[offset].rgba = result;
}
