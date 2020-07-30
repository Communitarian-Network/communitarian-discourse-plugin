## Installation
- git clone git@github.com:discourse/discourse.git
- git clone git@github.com:fs/communitarian-discourse-plugin.git communitarian
- cd discourse
- git checkout stable - we should work only on stable version of discourse
- cd plugins
- ln -s ../../communitarian .
- cd ..
- install dependencies([guide](https://github.com/discourse/discourse#development))
- run rails server
- visit http://localhost:3000/admin/plugins
- check communitarian presence

## Documentation
- [How to create plugin](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-1/30515)
- [How to install plugin](https://meta.discourse.org/t/install-plugins-in-discourse/19157)
- [How to install theme](https://meta.discourse.org/t/how-do-i-install-a-theme-or-theme-component/63682)
