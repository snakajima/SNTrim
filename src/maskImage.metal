//
//  maskImage.metal
//  SNTrim
//
//  Created by satoshi on 9/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void maskImage(device uchar* rgba [[ buffer(0) ]],
                      const device uint& width [[ buffer(1) ]],
                      const device uint& height [[ buffer(2) ]],
                      const device uint& extra [[ buffer(3) ]],

                      const uint tgPos [[ threadgroup_position_in_grid ]],
                      const uint tPerTg [[ threads_per_threadgroup ]],
                      const uint tPos [[ thread_position_in_threadgroup ]]) {
    
    uint offset = tgPos * tPerTg + tPos;
    uint index = offset * width * 4;
    uint end = index + width * 4;
    for(; index < end; index += 4) {
        rgba[index+3] = rgba[index];
    }
}