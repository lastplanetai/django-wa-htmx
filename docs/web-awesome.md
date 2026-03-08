# Web Awesome Reference

Quick reference for Web Awesome components and patterns used in this project.

## Setup

The kit script loads in `templates/base.html`:
```html
<script src="https://kit.webawesome.com/YOUR_KIT_ID.js" crossorigin="anonymous"></script>
```

Replace `YOUR_KIT_ID` with your kit ID from [webawesome.com](https://webawesome.com).

### FOUC Prevention (wa-cloak)

Web Awesome components render as unstyled HTML until the kit JS loads and
upgrades them. To prevent a flash of unstyled content:

```html
<html lang="en" class="wa-cloak">
<head>
    <style>.wa-cloak { visibility: hidden; }</style>
    <!-- WA kit removes the class once loaded -->
</head>
```

The kit script automatically removes the `wa-cloak` class from `<html>` once
all components are registered. **Without a valid kit URL, the page stays
invisible** — so never enable wa-cloak with a placeholder kit ID.

## Components

### wa-button

Renders a styled button. Use `href` to make it a link.

```html
<wa-button variant="brand" href="/donate/">Donate</wa-button>
<wa-button variant="brand" appearance="outlined" href="/learn-more/">Learn More</wa-button>
```

**Attributes:**
- `variant`: `neutral` (default), `brand`, `success`, `warning`, `danger`
- `appearance`: `accent`, `filled`, `filled-outlined`, `outlined`, `plain`
- `size`: `small`, `medium` (default), `large`
- `href`: renders as `<a>` instead of `<button>`
- `pill`: rounded corners
- `loading`: shows spinner
- `disabled`: grays out

**Slots:**
- `start` / `end`: icons alongside text

```html
<wa-button>
    <wa-icon slot="start" name="heart"></wa-icon>
    Donate
</wa-button>
```

### wa-card

Groups related content in a container.

```html
<wa-card>
    <img slot="media" src="..." alt="..." />
    <strong>Title</strong>
    <p>Content here</p>
    <wa-button slot="footer">Action</wa-button>
</wa-card>
```

**Attributes:**
- `appearance`: `outlined` (default), `filled`, `filled-outlined`, `plain`, `accent`
- `orientation`: `vertical` (default), `horizontal`

**Slots:**
- `media`: image/video at card start
- `header`: optional header
- `header-actions`: actions in header
- `footer`: optional footer
- `footer-actions`: actions in footer

**CSS custom properties:**
- `--spacing`: space around/between sections (default: `var(--wa-space-l)`)

**Note:** Consider whether `wa-card` is the right choice. For text-heavy content,
semantic HTML with CSS (e.g., `<article>`, `<section>`, or a `div` with a left
border accent) often reads better than cards. Reserve `wa-card` for media-rich
content or interactive elements.

### wa-details

Collapsible content sections. Groups with `name` attribute for accordion behavior.

```html
<wa-details summary="Section Title" name="group-name">
    <p>Collapsible content here.</p>
</wa-details>
```

**Attributes:**
- `summary`: the visible header text
- `name`: group name — only one detail with the same name can be open at a time
- `open`: starts expanded

### wa-icon

Displays an icon from the Web Awesome icon set.

```html
<wa-icon name="bars" label="Menu"></wa-icon>
<wa-icon name="heart" label="Favorite"></wa-icon>
<wa-icon library="fab" name="facebook" label="Facebook"></wa-icon>
```

**Attributes:**
- `name`: icon name (from Web Awesome icon library)
- `label`: accessible label for screen readers
- `library`: icon library (`fab` for Font Awesome brands)

### wa-input / wa-textarea

Form fields with built-in validation and styling.

```html
<wa-input label="Email *" name="email" type="email" required></wa-input>
<wa-textarea label="Message *" name="message" required></wa-textarea>
```

### wa-carousel

Image carousels with auto-loop support.

```html
<wa-carousel loop>
    <wa-carousel-item><img src="..." alt="..." /></wa-carousel-item>
    <wa-carousel-item><img src="..." alt="..." /></wa-carousel-item>
</wa-carousel>
```

### wa-avatar

User avatars with image or initials.

```html
<wa-avatar image="/static/images/staff/person.jpg" label="Person Name"></wa-avatar>
```

**Attributes:**
- `image`: URL of avatar image
- `label`: accessible label
- `initials`: fallback initials when no image
- `shape`: `circle` (default), `square`, `rounded`

## Layout Utilities

These are CSS classes (not custom elements). Include WA style utilities to use them.

### wa-stack

Vertical layout with consistent spacing. Great for forms, text content, page sections.

```html
<div class="wa-stack">
    <div>Item 1</div>
    <div>Item 2</div>
</div>
```

**Modifier classes:**
- `wa-align-items-start` / `center` / `end` / `stretch` (default) / `baseline`
- `wa-gap-0` through `wa-gap-3xl` (default: `--wa-space-m`)

### wa-cluster

Horizontal flex layout that wraps. Good for button groups, tags, badges.

```html
<div class="wa-cluster">
    <wa-button>One</wa-button>
    <wa-button>Two</wa-button>
    <wa-button>Three</wa-button>
</div>
```

### wa-grid

Auto-responsive grid layout. Great for card lists.

```html
<div class="wa-grid" style="--min-column-size: 250px">
    <div>Item 1</div>
    <div>Item 2</div>
    <div>Item 3</div>
</div>
```

**CSS custom properties:**
- `--min-column-size`: minimum column width before wrapping (default: `20ch`)

**Modifier classes:**
- `wa-gap-*`: gap between items
- `wa-span-grid`: on a child, spans all columns

### wa-split

Distributes items evenly across available space. Good for navs, headers, footers.

```html
<div class="wa-split">
    <div>Left</div>
    <div>Right</div>
</div>
```

**Direction:** `wa-split:row` (default) or `wa-split:column`

## Testing with Playwright

Web Awesome custom elements use Shadow DOM. Key testing patterns:

### Waiting for WA to load

The `PlaywrightE2ETestCase` base class auto-waits for WA by watching the
`wa-cloak` class removal. See `myproject/testing/playwright_e2e_testcase.py`.

### Querying wa-* elements

Playwright can query custom elements directly:

```python
# Find a wa-button by text content
expect(page.locator("wa-button:has-text('Donate')")).to_be_visible()

# Find wa-details by content
expect(page.locator("wa-details").filter(has_text="Section Title")).to_be_visible()

# Wait for Shadow DOM hydration (for interacting with internals)
from myproject.testing.playwright_e2e_testcase import wait_for_wa_component
wait_for_wa_component(page, "wa-button")
```

### Shadow DOM gotchas

- `wa-button` renders its visible text inside Shadow DOM, but `:has-text()`
  still works because Playwright pierces shadow roots by default.
- For CSS selectors that need to reach inside shadow DOM, use `>>` combinator:
  `page.locator("wa-card >> .card-body")`

## Design Tokens

WA uses CSS custom properties for theming. Common ones:

- `--wa-space-3xs` through `--wa-space-3xl`: spacing scale
- `--wa-color-brand-*`: brand color palette
- `--wa-font-size-*`: type scale
- `--wa-border-radius-*`: corner rounding

Override in `static/css/main.css` to customize the theme.

## Docs

- Components: https://webawesome.com/docs/components/
- Layout utilities: https://webawesome.com/docs/layout
- Stack: https://webawesome.com/docs/utilities/stack/
- Grid: https://webawesome.com/docs/utilities/grid/
- Split: https://webawesome.com/docs/utilities/split/
