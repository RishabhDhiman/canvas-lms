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

import React from 'react'
import {render, fireEvent, screen, waitFor} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import {ButtonsTray} from '../ButtonsTray'
import {useStoreProps} from '../../../shared/StoreContext'
import FakeEditor from '../../../shared/__tests__/FakeEditor'

jest.mock('../../../shared/StoreContext')

const startButtonsAndIconsUpload = jest.fn().mockResolvedValue({url: 'https://uploaded.url'})
useStoreProps.mockReturnValue({startButtonsAndIconsUpload})

const editor = {
  dom: {
    createHTML: jest.fn((tagName, {src, alt, ...rest}) => {
      const element = document.createElement(tagName)
      element.setAttribute('src', src)
      element.setAttribute('alt', alt)
      element.setAttribute('data-inst-buttons-and-icons', rest['data-inst-buttons-and-icons'])
      return element
    }),
    create: name => document.createElement(name)
  },
  insertContent: jest.fn()
}

describe('RCE "Buttons and Icons" Plugin > ButtonsTray', () => {
  const defaults = {
    editor,
    onUnmount: jest.fn(),
    editing: false
  }

  const renderComponent = componentProps => {
    return render(<ButtonsTray {...componentProps} />)
  }

  beforeAll(() => {
    ENV.DEEP_LINKING_POST_MESSAGE_ORIGIN = 'https://domain.from.env'

    global.fetch = jest.fn().mockResolvedValue({
      blob: () => Promise.resolve(new Blob())
    })
  })

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders the create view', () => {
    renderComponent(defaults)
    screen.getByRole('heading', {name: /buttons and icons/i})
  })

  it('closes the tray', async () => {
    const onUnmount = jest.fn()
    renderComponent({...defaults, onUnmount})
    userEvent.click(screen.getByText(/close/i))
    await waitFor(() => expect(onUnmount).toHaveBeenCalled())
  })

  it('uploads the svg', async () => {
    render(<ButtonsTray {...defaults} />)

    userEvent.click(screen.getByRole('button', {name: /apply/i}))
    await waitFor(() => {
      if (startButtonsAndIconsUpload.mock.calls.length <= 0) throw new Error()
      expect(startButtonsAndIconsUpload.mock.calls[0]).toMatchInlineSnapshot(`
        Array [
          Object {
            "domElement": <svg
              fill="none"
              height="122px"
              viewBox="0 0 122 122"
              width="122px"
              xmlns="http://www.w3.org/2000/svg"
            >
              <metadata>
                {"type":"image/svg+xml-buttons-and-icons","name":"","alt":"","shape":"square","size":"small","color":null,"outlineColor":null,"outlineSize":"small","text":"","textSize":"small","textColor":"#000000","textBackgroundColor":null,"textPosition":"middle","encodedImage":"","encodedImageType":"","encodedImageName":"","x":"50%","y":"50%","translateX":-54,"translateY":-54,"width":108,"height":108,"transform":"translate(-54,-54)"}
              </metadata>
              <svg
                fill="none"
                height="122px"
                viewBox="0 0 122 122"
                width="122px"
                x="0"
              >
                <g
                  fill="none"
                >
                  <clippath
                    id="clip-path-for-embed"
                  >
                    <rect
                      height="114"
                      width="114"
                      x="4"
                      y="4"
                    />
                  </clippath>
                  <rect
                    height="114"
                    width="114"
                    x="4"
                    y="4"
                  />
                </g>
              </svg>
              <style
                type="text/css"
              >
                @font-face {font-family: "Lato Extended";font-weight: bold;src: url(data:;base64,);}
              </style>
            </svg>,
            "name": "untitled.svg",
          },
          Object {
            "onDuplicate": false,
          },
        ]
      `)
    })
    await waitFor(() => expect(defaults.onUnmount).toHaveBeenCalled())
  })

  it('writes the content to the editor', async () => {
    render(<ButtonsTray {...defaults} />)

    fireEvent.change(document.querySelector('#button-alt-text'), {target: {value: 'banana'}})
    userEvent.click(screen.getByRole('button', {name: /apply/i}))
    await waitFor(() => expect(editor.insertContent).toHaveBeenCalled())
    expect(editor.insertContent.mock.calls[0]).toMatchInlineSnapshot(`
      Array [
        "<img src=\\"https://uploaded.url\\" alt=\\"banana\\" data-inst-buttons-and-icons=\\"true\\" data-download-url=\\"https://uploaded.url/?buttons_and_icons=1\\">",
      ]
    `)

    await waitFor(() => expect(defaults.onUnmount).toHaveBeenCalled())
  })

  it('writes the content to the editor without alt attribute', async () => {
    render(<ButtonsTray {...defaults} />)

    userEvent.click(screen.getByRole('button', {name: /apply/i}))
    await waitFor(() => expect(editor.insertContent).toHaveBeenCalled())
    expect(editor.insertContent.mock.calls[0]).toMatchInlineSnapshot(`
      Array [
        "<img src=\\"https://uploaded.url\\" data-inst-buttons-and-icons=\\"true\\" data-download-url=\\"https://uploaded.url/?buttons_and_icons=1\\">",
      ]
    `)

    await waitFor(() => expect(defaults.onUnmount).toHaveBeenCalled())
  })

  it('disables footer while submiting', async () => {
    render(<ButtonsTray {...defaults} />)

    const button = screen.getByRole('button', {name: /apply/i})
    userEvent.click(button)

    await waitFor(() => expect(button).toBeDisabled())
    await waitFor(() => expect(defaults.onUnmount).toHaveBeenCalled(), {
      timeout: 3000
    })
  })

  describe('when a button is being edited', () => {
    let ed

    beforeEach(() => {
      ed = new FakeEditor()

      // Add an image to the editor and select it
      ed.setContent(
        '<img id="test-image" src="https://canvas.instructure.com/svg" data-inst-buttons-and-icons="true" data-download-url="https://canvas.instructure.com/files/1/download" alt="a red circle" />'
      )
      ed.setSelectedNode(ed.dom.select('#test-image')[0])
    })

    const subject = () => render(<ButtonsTray onClose={jest.fn()} editing editor={ed} />)

    beforeEach(() => {
      global.fetch = jest.fn().mockResolvedValue({
        text: () =>
          Promise.resolve(`
            <svg height="100" width="100">
              <metadata>
                {
                  "name":"Test Image",
                  "alt":"a test image",
                  "shape":"triangle",
                  "size":"large",
                  "color":"#FF2717",
                  "outlineColor":"#06A3B7",
                  "outlineSize":"small",
                  "text":"Some Text",
                  "textSize":"medium",
                  "textColor":"#009606",
                  "textBackgroundColor":"#E71F63",
                  "textPosition":"middle"
                }
              </metadata>
              <circle cx="50" cy="50" r="40" stroke="black" stroke-width="3" fill="red"/>
            </svg>
          `)
      })
    })

    afterEach(() => jest.restoreAllMocks())

    it('loads the standard SVG metadata', async () => {
      const {getByLabelText, getByTestId} = subject()

      await waitFor(() => {
        expect(getByLabelText('Name').value).toEqual('Test Image')
        expect(getByLabelText('Button Shape').value).toEqual('Triangle')
        expect(getByLabelText('Button Size').value).toEqual('Large')
        expect(getByTestId('colorPreview-#FF2717')).toBeInTheDocument() // button color
        expect(getByTestId('colorPreview-#06A3B7')).toBeInTheDocument() // button outline
        expect(getByLabelText('Button Outline Size').value).toEqual('Small')
      })
    })

    it('loads the text-related SVG metadata', async () => {
      const {getByLabelText, getByTestId, getByText} = subject()

      await waitFor(() => {
        expect(getByText('Some Text')).toBeInTheDocument()
        expect(getByLabelText('Text Size').value).toEqual('Medium')
        expect(getByTestId('colorPreview-#009606')).toBeInTheDocument() // text color
        expect(getByTestId('colorPreview-#E71F63')).toBeInTheDocument() // text background color
        expect(getByLabelText('Text Position').value).toEqual('Middle')
      })
    })
  })
})
