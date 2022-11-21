'use babel'

import {Directory} from 'atom'
import getIconServices from './get-icon-services'

export default class MRUItemView {
  async initialize (listView, item) {
    this.listView = listView
    this.item = item

    this.element = document.createElement('li')
    this.element.itemViewData = this
    this.element.classList.add('two-lines')

    this.itemPath = null
    if (item.getPath && typeof item.getPath === 'function') {
      this.itemPath = item.getPath()
    }

    const repo = await MRUItemView.repositoryForPath(this.itemPath)
    if (repo != null) {
      const statusIconDiv = document.createElement('div')
      const status = repo.getCachedPathStatus(this.itemPath)
      if (repo.isStatusNew(status)) {
        statusIconDiv.className = 'status status-added icon icon-diff-added'
        this.element.appendChild(statusIconDiv)
      } else if (repo.isStatusModified(status)) {
        statusIconDiv.className = 'status status-modified icon icon-diff-modified'
        this.element.appendChild(statusIconDiv)
      }
    }

    this.firstLineDiv = this.element.appendChild(document.createElement('div'))
    this.firstLineDiv.classList.add('primary-line', 'file')
    if (typeof item.getIconName === 'function') {
      if (atom.config.get('tabs.showIcons')) this.firstLineDiv.classList.add('icon', 'icon-' + item.getIconName())
    } else {
      getIconServices().updateMRUIcon(this)
    }
    this.firstLineDiv.setAttribute('data-name', item.getTitle())
    this.firstLineDiv.innerText = item.getTitle()

    if (this.itemPath) {
      this.firstLineDiv.setAttribute('data-path', this.itemPath)
      const secondLineDiv = this.element.appendChild(document.createElement('div'))
      secondLineDiv.classList.add('secondary-line', 'path', 'no-icon')
      secondLineDiv.innerText = this.itemPath
    }
  }

  select () {
    this.element.classList.add('selected')
  }

  unselect () {
    this.element.classList.remove('selected')
  }

  static async repositoryForPath (filePath) {
    if (filePath) {
      return atom.project.repositoryForDirectory(new Directory(filePath))
    }
    return null
  }
}
