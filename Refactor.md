# Refactor

## `Slide`

- New Slide model — Slideshow/Slide.swift

```swift
struct Slide: Identifiable {
	let imageName: String
	let image: Image
	let id: UUID = UUID()
}
```

## `ContentView`

- Display a `ContentUnavailableView` if its `ViewModel` (see below) has an empty `.images` property
- Otherwise:
	- display `SlideView`, passing in the `ViewModel`'s array of `Slide` from its `.images` property, or
	- display `DefaultView`'s view: a view of the `ViewModel`'s `selectedImage` and buttons to:
		- Start the slide show at current image
		- Re-start slide show from beginning
	- `DefaultView` also accepts drag & drop of a folder/image and passes it to the `ViewModel`

## `ContentView.ViewModel`

- A new viewModel for `ContentView`. It will contain the login and workers to provide data to `ContentView`.
- Testable. We should write tests for it
- Its role is to provide:
	- `.images: [Slide]` - an array of `Slide`
	- `.selectedImage: Image`
	- `.index: Int` - the index of `.selectedImage` within `.images`. Checks it is always within `.images` bounds

- Handles methods currently in `DefaultView`:
	- `selectFileOrFolder`
	- `parseSelectedURL`
	- `getImagesAtURL`
	- `setHeroImage`

## `DefaultView`

- Becomes "just a View"; stops doing processing (it just passes drag & drop info to the `ViewModel`)
