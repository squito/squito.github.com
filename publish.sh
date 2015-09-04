#!/bin/sh
clear

echo ' '
echo "\033[0;36mPushing source to github\033[0m"
echo ' '

# Push source branch
git checkout source
git add -A
git commit
git push origin source


# Push master branch
jekyll b
git checkout master
git rm -qr .
cp -r _site/. .
rm -r _site
echo 'imranrashid.com' >> CNAME
git add -A
git commit -m 'update'
git push origin master --force

echo ''
echo "\033[0;36mPublished successfully. Moving back to source branch...\033[0m"
echo ' '

git checkout source

clear
echo ''
echo "\t\033[0;36m ⚐ \033[1;36mSweetness\033[0;36m\033[0m"
open http://imranrashid.com
