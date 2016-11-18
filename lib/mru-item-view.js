'use babel'

class MRUItemView extends HTMLElement {
  initialize(listView, item) {
    this.listView = listView
    this.item = item
    this.classList.add("two-lines")
    iconDiv = this.appendChild(document.createElement("div"))
    iconDiv.classList.add("status", "icon")
    firstLineDiv = this.appendChild(document.createElement("div"))
    firstLineDiv.classList.add("primary-line", "file", "icon")
    firstLineDiv.innerText = item.getTitle()
    secondLineDiv = this.appendChild(document.createElement("div"))
    secondLineDiv.classList.add("secondary-line", "path", "no-icon")
    secondLineDiv.innerText = item.getPath()
  }

  select() {
    this.classList.add("selected")
  }

  unselect() {
    this.classList.remove("selected")
  }
}

module.exports = document.registerElement(
  "tabs-mru-item", {prototype: MRUItemView.prototype, extends: "li"})
