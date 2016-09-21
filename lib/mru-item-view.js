'use babel'

class MRUItemView extends HTMLElement {
  initialize(listView, item) {
    this.listView = listView
    this.item = item
    this.innerText = item.getTitle()
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
