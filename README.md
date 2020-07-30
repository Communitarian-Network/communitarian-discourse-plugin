## Installation

- git clone git@github.com:discourse/discourse.git
- git clone git@github.com:fs/communitarian-discourse-plugin.git communitarian
- cd discourse
- git checkout stable - we should work only on stable version of discourse
- cd plugins
- ln -s ../../communitarian .
- cd ..
- install dependencies https://github.com/discourse/discourse#development
- run rails server
- visit http://localhost:3000/admin/plugins
- check communitarian presence

## Usage
