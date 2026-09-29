/// Development-mode mirror of ./gpuix-jsx-runtime.d.ts (jsxDEV entrypoint).

import type * as React from 'react'
import type * as Real from '../node_modules/@gpuix/react/jsx-dev-runtime'

export { jsxDEV, jsxDEV as jsx, jsxDEV as jsxs, Fragment } from 'react/jsx-dev-runtime'

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
