# Instagrab ![CI](https://github.com/KevCui/instagrab/workflows/CI/badge.svg)

> Grab images and videos and more from Instagram

## Table of Contents

- [Features](#features)
- [Dependency](#dependency)
- [Download](#download)
- [Usage](#usage)
  - [Example](#example)
- [How to run tests](#how-to-run-tests)
- [Disclaimer](#disclaimer)

## Features

- Single Bash script
- No need to sign in Instagram account
- No need to register Instagram API
- Download images and videos from Instagram directly
- Download JSON data in additional, including profile data, image/video data...
- Download only contents published in any time period
- Toggle image download, or/and video download, or/and JSON data download

## Dependency

- [curl](https://curl.haxx.se/download.html)
- [jq](https://stedolan.github.io/jq/download/)

## Download

```bash
~$ wget https://raw.githubusercontent.com/KevCui/Instagrab/master/instagrab.sh
~$ chmod +x instagrab.sh
```

## Usage

```
Usage:
  ./instagrab.sh -u <username> [-d] [-i] [-v] [-f <yyyymmdd>] [-t <yyyymmdd>]

Options:
  -u               required, Instagram username
  -d               optional, skip JSON data download
  -i               optional, skip image download
  -v               optional, skip video download
  -f <yyyymmdd>    optional, from date, format yyyymmdd
  -t <yyyymmdd>    optional, to date, format yyyymmdd
```

### Example

- Download images, videos and JSON data from `@instagram` account, published since `21 August 2020`:

```
~$ ./instagrab.sh -u instagram -f 20200821
[INFO] Find 6457 post(s), 130 page(s)
[INFO] Checking 1/130...
...
```

After the execution, the downloaded images, videos and JSON data can be found inside `~/instagram_<unixtime>` folder

## How to run tests

```bash
~$ bats test/instagrab.bats
```

## Disclaimer

The purpose of this script is to download media contents from Instagram in order to backup and archive them. Please do NOT copy or distribute downloaded contents to others. Please do remember that the copyright of contents always belongs to the owner of Instagram account. Please use this script at your own responsibility.
