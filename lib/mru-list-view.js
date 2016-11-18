'use babel'

import MRUItemView from './mru-item-view'
import {CompositeDisposable} from 'atom'

class MRUListView extends HTMLElement {
  initialize(pane) {
    parentDiv = document.createElement('div')
    parentDiv.appendChild(this)
    parentDiv.classList.add("select-list", "fuzzy-finder")
    
    this.pane = pane
    this.subscribe()
    this.panel = atom.workspace.addModalPanel({
      item: parentDiv,
      visible: false,
      class: 'tabs-mru-list'
    })
    this.classList.add("list-group")
  }

  subscribe() {
    this.subscriptions = new CompositeDisposable()

    /* Because the chosen item is passed in the callback, both the
    ChooseNext and ChooseLast events can call our our single choose
    method. */
    this.subscriptions.add(
      this.pane.onChooseNextMRUItem((item) => this.choose(item)))
    this.subscriptions.add(
      this.pane.onChooseLastMRUItem((item) => this.choose(item)))

    this.subscriptions.add(
      this.pane.onDoneChoosingMRUItem(() => this.stopChoosing()))

    this.subscriptions.add(
      this.pane.onDidDestroy(() => this.unsubscribe()))
  }

  unsubscribe() {
    this.subscriptions.dispose()
  }

  choose(selectedItem) {
    this.show(selectedItem)
  }

  stopChoosing() {
    this.hide()
  }

  show(selectedItem) {
    if (!this.panel.visible) {
      this.buildListView(selectedItem)
      this.panel.show()
    }
    else {
      this.updateSelectedItem(selectedItem)
    }
  }

  hide() {
    if (this.panel.visible) {
      this.panel.hide()
    }
  }

  updateSelectedItem(selectedItem) {
    for (let itemView of this.children) {
      if (itemView.item === selectedItem)
        itemView.select()
      else
        itemView.unselect()
    }
  }

  buildListView(selectedItem) {
    /* Making this more efficient, and not simply building the view for the
    entire stack every time it's shown, has significant complexity cost. As
    is, the pane system completely owns the MRU stack. Adding events and
    handlers to incrementally update the UI here would mean two copies of
    the stack to maintain and keep in sync. Let's take on that complexity
    only if we decide the MRU stack should be infinite and this UI must
    support that somehow. */
    while (this.firstChild)
      this.removeChild(this.firstChild)

    /* We're inserting each item at the top so we traverse the stack from
    the bottom, resulting in the most recently used item at the top of the
    UI. */
    for (let i = this.pane.itemStack.length-1; i >= 0; i--) {
      let item = this.pane.itemStack[i]
      let itemView = new MRUItemView()
      itemView.initialize(this, item)
      this.appendChild(itemView)
      if (item === selectedItem)
        itemView.select()
    }
  }

}

module.exports = document.registerElement(
  "tabs-mru-list", {prototype: MRUListView.prototype, extends: "ol"})
