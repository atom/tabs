'use babel'

import FileIcons from './file-icons'
import path from 'path'

class MRUItemView extends HTMLElement {
  initialize (listView, item) {
    this.listView = listView
    this.item = item
    this.classList.add('two-lines')

    let itemPath = null
    if (item.getPath && typeof item.getPath === 'function') {
      itemPath = item.getPath()
    }

    const repo = MRUItemView.repositoryForPath(itemPath)
    if (repo != null) {
      const statusIconDiv = document.createElement('div')
      const status = repo.getCachedPathStatus(itemPath)
      if (repo.isStatusNew(status)) {
        statusIconDiv.className = 'status status-added icon icon-diff-added'
        this.appendChild(statusIconDiv)
      } else if (repo.isStatusModified(status)) {
        statusIconDiv.className = 'status status-modified icon icon-diff-modified'
        this.appendChild(statusIconDiv)
      }
    }

    const firstLineDiv = this.appendChild(document.createElement('div'))
    firstLineDiv.classList.add('primary-line', 'file')
    let typeClasses = FileIcons.getService().iconClassForPath(itemPath, 'tabs-mru-switcher')
    if (typeClasses) {
      if (!Array.isArray(typeClasses)) typeClasses = typeClasses.split(/\s+/g)
      if (typeClasses) firstLineDiv.classList.add('icon', ...typeClasses)
    }
    firstLineDiv.setAttribute('data-name', item.getTitle())
    firstLineDiv.innerText = item.getTitle()

    if (itemPath) {
      const secondLineDiv = this.appendChild(document.createElement('div'))
      secondLineDiv.classList.add('secondary-line', 'path', 'no-icon')
      secondLineDiv.innerText = itemPath
    }
  }

  select () {
    this.classList.add('selected')
  }

  unselect () {
    this.classList.remove('selected')
  }

  static repositoryForPath (filePath) {
    if (filePath) {
      const projectPaths = atom.project.getPaths()
      for (let i = 0; i < projectPaths.length; i++) {
        if (filePath === projectPaths[i] || filePath.startsWith(projectPaths[i] + path.sep)) {
          return atom.project.getRepositories()[i]
        }
      }
    }
    return null
  }
}

module.exports = document.registerElement(
  'tabs-mru-item', {prototype: MRUItemView.prototype, extends: 'li'})
