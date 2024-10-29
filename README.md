# mint.nvim 🍃

**mint** stands for **Mark Intuition and Navigation Tweaks**. This Neovim plugin enhances your experience with marks by providing intuitive navigation and display options.

## Features ✨

- **Column Sign Display**: View marks directly on the column sign for easy identification.
- **Marks Navigation Popup**: Use the default binding `m?` to open a popup for navigating through marks.
  - 🗑️ **Marks Deletion**: Quickly delete marks from the popup.
  - 🧭 **Easy Navigation**: Effortlessly navigate to marks with a few keystrokes.

## Installation ⚙️

### Lazy Installation

To install **mint.nvim** using [lazy.nvim](https://github.com/folke/lazy.nvim), add the following line to your Neovim configuration:

```lua
return {
    'gabrielfruet/mint.nvim',
    config = function()
        local mint = require('mint')
        mint.setup{}
    end
}
```

## Usage 📚

After installation, you can start using the plugin by:
- Opening the marks navigation popup with `m?`.

## Contributing 🤝

Contributions are welcome! Please feel free to open issues or submit pull requests.

## License 📄

This project is licensed under the MIT License.

## Acknowledgements 🙏

Thanks for using **mint.nvim**! Your feedback is appreciated.
