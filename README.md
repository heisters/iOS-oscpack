iOS-oscpack
===========

An Objective-C interface to oscpack for iOS.

NB. in order to use this library, the including implementation file will need
to be compiled as Objective-C++ by setting its file extension to ".mm".

oscpack
-------

The version of oscpack included in this project is modified from the original
to check for `__arm64__` definition in the same places it looks for
`__x86_64__`. These issues will only surface when running on a device because
the iOS simulator is x86-64.
