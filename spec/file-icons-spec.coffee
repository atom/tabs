DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

describe 'file icon handling', ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage('tabs')

  it 'allows the service to provide icon classes', ->
    fileIconsDisposable = atom.packages.serviceHub.provide 'atom.file-icons', '1.0.0', {
      iconClassForPath: (path, context) ->
        expect(context).toBe('tabs')
        'first-icon-class second-icon-class'
    }

    tab = workspaceElement.querySelector('.tab')
    expect(tab.itemTitle.className).toBe('title icon first-icon-class second-icon-class')

    fileIconsDisposable.dispose()
    expect(tab.itemTitle.className).toBe('title')

  it 'allows the service to provide multiple classes as an array', ->
    atom.packages.serviceHub.provide 'atom.file-icons', '1.0.0', {
      iconClassForPath: (path) -> ['first-icon-class', 'second-icon-class']
    }

    tab = workspaceElement.querySelector('.tab')
    expect(tab.itemTitle.className).toBe('title icon first-icon-class second-icon-class')
