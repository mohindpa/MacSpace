# Privacy

MacSpace is designed to work locally. The Mac bridge and iPad web client
communicate directly over the user's local network; the core keyboard, mouse,
clipboard, and application-control traffic does not go through a MacSpace
cloud service.

MacSpace may access the following data when the user chooses the related
feature:

- Accessibility state, so macOS can accept generated keyboard and mouse events
- The list of running applications and their icons
- The current Mac clipboard, when the Clipboard panel is opened or refreshed
- Text entered into the iPad client, so it can be typed or pasted on the Mac
- Local connection details such as the Mac host name, port, and status

The iPad client stores layouts, themes, snippets, and the access token in the
browser's local storage. The bridge stores its access token and log locally in
the MacSpace application-support directory.

The optional Buy Me a Coffee button loads JavaScript from a third-party CDN.
That widget is not required for MacSpace to operate and can be removed by
users who do not want the optional external request.

MacSpace currently uses plain HTTP for local-network communication. Use it only
on a trusted network and never forward port `8787` to the internet.
