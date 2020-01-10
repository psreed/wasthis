#!/bin/sh

if [ ! -d "${PT_install_dir}" ]; then 
  echo "Installation directory does not exist"
  exit 1
fi

if [ ! -f "${PT_filename}" ]; then 
  echo "IBM Package Utility Zip File does not exist"
  exit 1
fi

cd $PT_install_dir
unzip -o $PT_filename