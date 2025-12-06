# PSA LearningHUB - Corporate Learning Branch (CLB) Development Environment

Spin up a local install of the CLB LearningHUB with theme and plugin installed and configured.

## Get Started

Currently requires [Docker](https://www.docker.com/) installed on your system. If you're on Windows, use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

`git clone https://github.com/PSA-Corporate-Learning-Branch/learninghub-dev.git`

`cd learninghub-dev`

`docker compose up --build`

- Navigate your web browser to `http://localhost:8181/learninghub/` to see your site.
- Login at the normal `/learninghub/wp-admin` URL with `admin` and `admin` as the user/pass.
- Then go to [the production version of the site](https://corporatelearning.gww.gov.bc.ca/learninghub/wp-admin/export.php) and download its XML export file.
- Then go to the dashboard of your local install and go to `Tools > WordPress Run Importer` and upload the XML you just downloaded
- Voila! You should now have a fully operational localised LearningHUB to develop upon

## Contributing

Before making changes, review [`AGENTS.md`](AGENTS.md) for project structure, coding standards, and pull request expectations.
