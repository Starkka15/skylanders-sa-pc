// skylanders_sa - fills the projected-shadow placeholder texture.
//
// sub_829045A8 (game init) creates a 1x1 k_8_8_8_8 texture (name hash 7C308D38, pointer kept
// at 0x82BAA48C) for the projected blob shadow that follows the player. The ground pixel shader
// (3C54591D9DC5D774, branch on b128) samples it through tf3 inside the projector's square:
// texel .z is compared against the projected depth, .x is the shadow intensity. The game never
// renders into or writes this texture, so the picture depends on whatever the page held. Here
// the page is always zero, so everything inside the square fails the compare and goes dark (the
// "shadow square that moves with Spyro"). A white texel (depth 1, intensity 1) means "not
// shadowed", the same as the game's own white 1x1 texture (sub_82632728).

#include "generated/default/skylanders_sa_init.h"

#include <rex/cvar.h>
#include <rex/hook.h>
#include <rex/logging.h>

REX_EXTERN(__imp__sub_829045A8);
REX_EXTERN(__imp__sub_82891A40);

#include <atomic>
#include <cmath>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <string>

// Diagnostic: sub_82891A40 runs the per-tile shadow classifier, either sub_8213FCC0 (flag at
// 0x82BB4574 set) or sub_821404D8 (clear). On hardware both agree. With SKY_CLASSDIFF set, run
// both on the same inputs every call and, every 5 s, log the tiles where they differ. The class
// buffer is the 35x22 tile grid at 0x1C2BEA80 (second half starts 15 bytes later).
REX_HOOK_RAW(sub_82891A40) {
  static const bool diff = std::getenv("SKY_CLASSDIFF") != nullptr;
  if (!diff) {
    __imp__sub_82891A40(ctx, base);
    return;
  }
  constexpr uint32_t kFlag = 0x82BB4574;
  constexpr uint32_t kGrid = 0x1C2BEA80;  // physical; read through the A0 view
  constexpr uint32_t kGridVa = 0xBC2BEA80;
  constexpr uint32_t kGridBytes = 785;
  uint32_t flag = REX_LOAD_U32(kFlag);
  PPCContext saved = ctx;
  uint8_t a[kGridBytes], b[kGridBytes];
  REX_STORE_U32(kFlag, 0);
  __imp__sub_82891A40(ctx, base);
  std::memcpy(a, base + kGridVa, kGridBytes);
  ctx = saved;
  REX_STORE_U32(kFlag, 1);
  __imp__sub_82891A40(ctx, base);
  std::memcpy(b, base + kGridVa, kGridBytes);
  REX_STORE_U32(kFlag, flag);
  (void)kGrid;

  static std::atomic<int64_t> last{0};
  int64_t now = std::chrono::duration_cast<std::chrono::seconds>(
                    std::chrono::steady_clock::now().time_since_epoch())
                    .count();
  int64_t prev = last.load();
  if (now - prev < 5 || !last.compare_exchange_strong(prev, now)) {
    return;
  }
  int differ = 0;
  for (uint32_t tile = 0; tile < 770; ++tile) {
    uint32_t i = tile + (tile >= 385 ? 15 : 0);
    differ += a[i] != b[i];
  }
  REXLOG_INFO("classdiff: {} of 770 tiles differ (A = sub_821404D8, B = sub_8213FCC0); "
              "row: A grid | B grid",
              differ);
  for (uint32_t row = 0; row < 22; ++row) {
    std::string la, lb;
    for (uint32_t col = 0; col < 35; ++col) {
      uint32_t tile = row * 35 + col;
      uint32_t i = tile + (tile >= 385 ? 15 : 0);
      la += fmt::format("{:X}", a[i] & 0xF);
      lb += fmt::format("{:X}", b[i] & 0xF);
    }
    REXLOG_INFO("classdiff {:2}: {} | {}", row, la, lb);
  }
}

// Diagnostic: sub_82144228 is classifier A's inner loop. It reads 1024 bytes of resolved depth
// at r3 (32-bit words, big-endian, depth in the top 24 bits as 20e4 float, stencil low byte)
// and picks a cascade per pixel from the reconstructed distance. With SKY_DEPTHIN set, log r3
// and a decoded sample every 5 s.
//
// The fix: the GPU resolves that depth into guest memory only on the GPU side, so without
// readback the CPU reads zeros and picks the wrong cascade for whole tiles (the "shadow square
// that moves with Spyro"). Hand the address the classifier reads to the SDK's
// readback_resolve_addresses, which reads back only the resolve covering it. Updated when the
// buffer moves (a new allocation, more than 4 MiB away); the first frame after a move still
// reads the old data. Left alone when the user set the cvar themselves. The GPU thread reads
// the cvar without a lock; an 8-character value stays in std::string's inline buffer, so a
// write racing a read can at worst give one torn parse, fixed on the next resolve.
REX_EXTERN(__imp__sub_82144228);
REX_HOOK_RAW(sub_82144228) {
  static const bool user_set = rex::cvar::HasNonDefaultValue("readback_resolve_addresses");
  static std::atomic<uint32_t> listed{0};
  if (!user_set) {
    uint32_t phys = ctx.r3.u32 & 0x1FFFFFFF;
    uint32_t prev = listed.load(std::memory_order_relaxed);
    if (!prev || (phys > prev ? phys - prev : prev - phys) > 0x400000) {
      if (listed.compare_exchange_strong(prev, phys)) {
        rex::cvar::SetFlagByName("readback_resolve_addresses", fmt::format("{:08X}", phys));
        REXLOG_INFO("shadow_fix: reading back the depth resolve covering {:08X}", phys);
      }
    }
  }
  static const bool on = std::getenv("SKY_DEPTHIN") != nullptr;
  if (on) {
    static std::atomic<int64_t> last{0};
    int64_t now = std::chrono::duration_cast<std::chrono::seconds>(
                      std::chrono::steady_clock::now().time_since_epoch())
                      .count();
    int64_t prev = last.load();
    if (now - prev >= 5 && last.compare_exchange_strong(prev, now)) {
      uint32_t src = ctx.r3.u32;
      REXLOG_INFO("depthin: r3={:08X} r4={:08X} r5={:08X} r6={:08X} r7={:08X} r8={:08X}", src,
                  ctx.r4.u32, ctx.r5.u32, ctx.r6.u32, ctx.r7.u32, ctx.r8.u32);
      for (uint32_t row = 0; row < 8; ++row) {
        std::string raw, dec;
        for (uint32_t i = 0; i < 8; ++i) {
          uint32_t w = REX_LOAD_U32(src + row * 128 + i * 4);
          uint32_t d = w >> 8;
          uint32_t e = (d >> 20) & 0xF, m = d & 0xFFFFF;
          float f = e ? std::ldexp(1.0f + m / 1048576.0f, int(e) - 15)
                      : std::ldexp(m / 1048576.0f, -14);
          raw += fmt::format("{:08X} ", w);
          dec += fmt::format("{:.6f} ", f);
        }
        REXLOG_INFO("depthin +{:3}: {}| {}", row * 128, raw, dec);
      }
    }
  }
  __imp__sub_82144228(ctx, base);
}

REX_HOOK_RAW(sub_829045A8) {
  __imp__sub_829045A8(ctx, base);
  constexpr uint32_t kPlaceholderPtr = 0x82BAA48C;
  uint32_t tex = REX_LOAD_U32(kPlaceholderPtr);
  if (!tex) {
    REXLOG_WARN("shadow_fix: projected-shadow placeholder texture missing");
    return;
  }
  // Fetch constant dword 1 (base address in the upper 20 bits) is at +0x34 of the object.
  uint32_t fetch1 = REX_LOAD_U32(tex + 0x34);
  uint32_t data = fetch1 & 0xFFFFF000u;
  REX_STORE_U32(data, 0xFFFFFFFFu);
  REXLOG_INFO("shadow_fix: placeholder texture {:08X} data {:08X} filled white", tex, data);
}
