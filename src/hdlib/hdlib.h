/**
 * @file
 * A quick, but inflexible extension of GRAPHX for displaying graphics.
 *
 * @authors ThelastMillennail
 */

#ifndef HDLIB_H
#define HDLIB_H

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <graphx.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Sprite (image) type.
 *
 * Whether or not a sprite includes transparency is not explicitly encoded, and
 * is determined only by usage. If used with transparency, transparent pixels
 * are those with a certain color index, which can be set with
 * gfx_SetTransparentColor().
 *
 * @note
 * Displaying a gfx_rletsprite_t (which includes transparency) is significantly
 * faster than displaying a gfx_sprite_t with transparency, and should be
 * preferred. However, gfx_rletsprite_t does not support transformations, such
 * as flipping and rotation. Such transformations can be applied to a
 * gfx_sprite_t, which can then be converted to a gfx_rletsprite_t for faster
 * display using gfx_ConvertToNewRLETSprite() or gfx_ConvertToRLETSprite().
 *
 * @remarks
 * Create at compile-time with a tool like
 * <a href="https://github.com/mateoconlechuga/convimg" target="_blank">convimg</a>.
 * Create at runtime (with uninitialized data) with gfx_MallocSprite(),
 * gfx_UninitedSprite(), or gfx_TempSprite().
 */


/**
 * Scales an unclipped 160x120 sprite to 320x240 at XY (0,0).
 *
 * @param[in] sprite Pointer to an initialized sprite structure.
 */
void hdl_ScaleHalfResSpriteFullscreen_NoClip(const gfx_sprite_t *sprite);

/**
 * Scales an unclipped transparent sprite 160x120 sprite to 320x240 at XY (0,0).
 * Transparent Index must be at 2.
 *
 * @param[in] sprite Pointer to an initialized sprite structure.
 */
void hdl_ScaleHalfResTransparentSpriteFullscreen_NoClip(const gfx_sprite_t *sprite);

#ifdef __cplusplus
}
#endif

#endif /* HDLIB_H */
