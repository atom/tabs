DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

describe 'FileIcons', ->
  afterEach ->
    FileIcons.setService(new DefaultFileIcons)

  it 'provides a default', ->
    expect(FileIcons.getService()).toBeDefined()
    expect(FileIcons.getService()).not.toBeNull()

  it 'allows the default to be overridden', ->
    service = new Object
    FileIcons.setService(service)

    expect(FileIcons.getService()).toBe(service)

  it 'allows the service to be reset to the default easily', ->
    service = new Object
    FileIcons.setService(service)
    FileIcons.resetService()

    expect(FileIcons.getService()).not.toBe(service)


  describe 'Class handling', ->
    workspaceElement = null
    
    beforeEach ->
      workspaceElement = atom.views.getView(atom.workspace)
      
      waitsForPromise ->
        atom.workspace.open('sample.js')
        
      waitsForPromise ->
        atom.packages.activatePackage('tabs')
  
    it 'allows multiple classes to be passed', ->
      service =
        iconClassForPath: (path) -> 'first second'
      
      FileIcons.setService(service)
      tab = workspaceElement.querySelector('.tab')
      tab.updateIcon()
      expect(tab.itemTitle.className).toBe('title icon first second')

    it 'allows an array of classes to be passed', ->
      service =
        iconClassForPath: (path) -> ['first', 'second']
      
      FileIcons.setService(service)
      tab = workspaceElement.querySelector('.tab')
      tab.updateIcon()
      expect(tab.itemTitle.className).toBe('title icon first second')

    it 'passes a TabView reference as iconClassForPath\'s second argument', ->
      FileIcons.setService
        iconClassForPath: (path, tab) -> tab.constructor.name
      tab = workspaceElement.querySelector('.tab')
      tab.updateIcon()
      expect(tab.itemTitle.className).toBe('title icon tabs-tab')
