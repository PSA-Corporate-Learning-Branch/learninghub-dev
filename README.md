# PSA WordPress - Corporate Learning Branch (CLB) Development Environment

Spin up a local install of the CLB WordPress platform with multisite, themes and plugins installed and configured.

## Get Started

Currently requires [Docker](https://www.docker.com/) installed on your system. If you're on Windows, use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

`git clone https://github.com/PSA-Corporate-Learning-Branch/wordpress-dev.git`

`cd wordpress-dev`

`docker compose up --build`

- Navigate your web browser to `http://localhost:8181` to see your site. Login at the normal `\wp-admin` URL.
- From here, you'll want to login and create the network site you're interested in developing upon.
- Then go to the production version of that site and download its XML export file. 
- Then go to the dashboard of your newly created network site and go to `Tools > WordPress Run Importer` and upload the XML you just downloaded
- Voila! You should now have a fully operational localised WordPress platform to develop upon.
- Currently the WP user/pass is set as admin/admin

## Contributing

Before making changes, review [`AGENTS.md`](AGENTS.md) for project structure, coding standards, and pull request expectations.
