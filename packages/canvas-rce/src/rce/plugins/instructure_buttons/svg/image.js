/*
 * Copyright (C) 2021 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import {createSvgElement} from './utils'
import {CLIP_PATH_ID} from './clipPath'
import {Shape} from './shape'
import {Size} from './constants'

export function buildImage(settings) {
  // Don't attempt to embed an image if none exist
  if (!settings.encodedImage) return

  const group = createSvgElement('g', {'clip-path': `url(#${CLIP_PATH_ID})`})
  const image = createSvgElement('image', {
    x: settings.x,
    y: settings.y,
    transform: settings.transform,
    width: settings.width,
    height: settings.height,
    href: settings.encodedImage
  })

  group.appendChild(image)

  return group
}

/**
 * Calculates the transformation props for a given
 * shape and size.
 *
 * A Transform takes the following shape:
 * {
 *   x: string,
 *   y: string,
 *   width: number,
 *   height: number,
 *   translateX: number,
 *   translateY: number
 * }
 *
 * @param {Shape} shape
 * @param {Size} size
 *
 * @returns Transform
 */
export function transformForShape(shape, size) {
  switch (shape) {
    case Shape.Pentagon:
      return transformForPentagon(size)
    case Shape.Triangle:
      return transformForTriangle(size)
    case Shape.Star:
      return transformForStar(size)
    case Shape.Square:
      return transformForSquare(size)
    case Shape.Circle:
      return transformForCircle(size)
    case Shape.Hexagon:
      return transformForHexagon(size)
    case Shape.Octagon:
      return transformForOctagon(size)
    default:
      return transformForDefault(size)
  }
}

function transformForPentagon(size) {
  const defaults = transformForDefault(size)
  return {
    ...defaults,
    y: '55%'
  }
}

function transformForTriangle(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(24),
        y: '65%'
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(50),
        y: '65%'
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(80),
        y: '65%'
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(112),
        y: '65%'
      }
  }
}

function transformForStar(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(8),
        y: '55%'
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(24),
        y: '55%'
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(44),
        y: '55%'
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(72),
        y: '55%'
      }
  }
}

function transformForSquare(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(60)
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(108)
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(142)
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(200)
      }
  }
}

function transformForCircle(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(54)
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(100)
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(132)
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(180)
      }
  }
}

function transformForHexagon(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(28)
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(68)
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(100)
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(160)
      }
  }
}

function transformForOctagon(size) {
  switch (size) {
    case Size.ExtraSmall:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(36)
      }
    case Size.Small:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(80)
      }
    case Size.Medium:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(110)
      }
    case Size.Large:
      return {
        ...transformForDefault(size),
        ...dimensionAttrsFor(180)
      }
  }
}

function transformForDefault(size) {
  const dimensions = {
    [Size.ExtraSmall]: 60,
    [Size.Small]: 75,
    [Size.Medium]: 80,
    [Size.Large]: 110
  }

  return {
    x: '50%',
    y: '50%',
    ...dimensionAttrsFor(dimensions[size])
  }
}

function translationFor(width) {
  return (width / 2) * -1
}

function dimensionAttrsFor(width) {
  return {
    width,
    height: width,
    translateX: translationFor(width),
    translateY: translationFor(width)
  }
}
