DefaultFileIcons = require '../lib/default-file-icons'

describe 'DefaultFileIcons', ->
  [fileIcons] = []

  beforeEach ->
    fileIcons = new DefaultFileIcons

  it 'does not provide icons out of the box', ->
    expect(fileIcons.iconClassForPath('foo.bar')).toEqual('')
    expect(fileIcons.iconClassForPath('README.md')).toEqual('')
    expect(fileIcons.iconClassForPath('foo.zip')).toEqual('')
    expect(fileIcons.iconClassForPath('foo.png')).toEqual('')
    expect(fileIcons.iconClassForPath('foo.pdf')).toEqual('')
    expect(fileIcons.iconClassForPath('foo.exe')).toEqual('')
