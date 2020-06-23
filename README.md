# Instagrab

> Grab images and videos and more from Instagram

## Table of Contents

- [Features](#features)
- [Dependency](#dependency)
- [Usage](#usage)
- [How to run tests](#how-to-run-tests)
- [Disclaimer](#disclaimer)

## Features

- No need to sign in Instagram account
- No need to register Instagram API
- Download images and videos from Instagram directly
- Download json data in additional, including profile data, image/video data...
- Toggle image download, or/and video download, or/and json data download
- Download only contents published in any time period

## Dependency

- [curl](https://curl.haxx.se/download.html)
- [jq](https://stedolan.github.io/jq/download/)

## Usage

```
Usage:
  ./instagrab.sh -u <username> [-d] [-i] [-v] [-f <yyyymmdd>] [-t <yyyymmdd>]

Options:
  -u               required, Instagram username
  -d               optional, skip json data download
  -i               optional, skip image download
  -v               optional, skip video download
  -f <yyyymmdd>    optional, from date, format yyyymmdd
  -t <yyyymmdd>    optional, to date, format yyyymmdd
```

## How to run tests

```bash
~$ bats test/instagrab.bats
```

## Disclaimer

The purpose of this script is to download media contents from Instagram in order to backup and archive them. Please do NOT copy or distribute downloaded contents to others. Please do remember that the copyright of contents always belongs to the owner of Instagram account. Please use this script at your own responsibility.
