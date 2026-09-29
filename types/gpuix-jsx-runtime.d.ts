/// JSX types for the pinned GPUix runtime.
///
/// @gpuix/react declares `IntrinsicAttributes` as a type alias to React's, and
/// TypeScript merges only interfaces into component attribute checks, so every
/// `key` passed to a component was a type error. The alias below extends the
/// package's own IntrinsicAttributes (and therefore its element set), adding the
/// key React's JSX runtime accepts — matching the `key` already on `Props` for
/// intrinsic elements. Remove this override once the pin ships an interface."

import type * as React from 'react'
import type * as Real from '../node_modules/@gpuix/react/jsx-runtime'

export { jsx, jsxs, Fragment } from 'react/jsx-runtime'

export namespace JSX {
  type ElementType = Real.JSX.ElementType
  type Element = Real.JSX.Element
  type ElementClass = Real.JSX.ElementClass
  type ElementAttributesProperty = Real.JSX.ElementAttributesProperty
  type ElementChildrenAttribute = Real.JSX.ElementChildrenAttribute
  type IntrinsicClassAttributes<T> = Real.JSX.IntrinsicClassAttributes<T>
  type IntrinsicElements = Real.JSX.IntrinsicElements
  interface IntrinsicAttributes extends React.Attributes {
    key?: React.Key | null | undefined
  }
}
