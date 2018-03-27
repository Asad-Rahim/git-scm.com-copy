# git-sync

**git-sync** is an automated synchronization of remote Git repositories with auto conflict solving.

## Scenarios of usage

* Auto syncronizations of remote Git-repositories.
* Share a repository with limited internet access with your partners.
* Keeping of repositories neat and sane between customers and clients.

## Run and play

If you will run **git-sync** without a parameter, then a test environment will be created.<br/>
You will get two remote and two local interconnected repositories on your machine.<br/>

## How it works

Imagine, there are two remote repositories. Each repository is a separate side.<br/>
You agreed that
* the first repository owns the prefix **foo-**
* the second repository owns the prefix **bar/**
* (the names are arbitrary)

Only branches with such the prefixes will be synchronized and visible on both sides.

Git-conflicts solving.<br/>
Conflicts may occur only if your merge or commit to another side.<br/>
The prefix owner will win in case of any conflicting git-commits. Commits of a loser will be rejected, but he just has to repeat his commits again from his local repository after a Git update.<br/>
The package is prepared, but does not include conflict informing. For this reason, you can ask your another side to perform git-merge or just recheck your action after run of **git-sync** and repeat if needed.

For now, Git-tags are excluded from synchronization.<br/>

## FAQ

**Why is everything done so?** - This is a proven and working solution. But I am open for ideas.<br/>
**Why do not synchronize everything at once?** - You will spend significant resources to cover this and make everything professional.<br/>
**Is it possible to synchronize all branches and tags?** - Yes. I have another [solutions and ideas](http://blog.it3xl.com/2018/02/approaches-to-synchronize-git-repos.html). No one is interested.<br/>
**Why do not sync Git-tags?** - This is disabled because some popular Git-servers block deletion of tags.

## I warned you

Most of the following sections describe technical deatails.<br/>
if you are techically savvy, I expect you will complete everything from one day to one week. Depends on your situation and needs.<br/>
The only thing I want to say. This is really working and live solution.<br/>
I wait for your notes and wish you luck.

## Wish to pay for a box?

If you are not ready to spend your time, ask me to do it for you.

I am offering a complete package that includes

* Working solution
* One year support
* Automated backups of your repositories
* Notifications about conflict solving or branche deletion
* reasonable customizations

Contact me at [it3xl.com](it3xl.com) if your are interesting.

## Features

* Prevention of an occasional deletion of an entire repository.
* Deletion and creation of branches in the foreign repository.
* Auto conflict resolving by [Convention over Git](http://blog.it3xl.com/2017/09/convention-over-git.html) (non-fast-forward branch conflicts).
* Recreation of the synchronization from any position and from scratch.
* Failover & auto recovery of synchronization is supported. Especially for network troubles.
* Solution is applied per-repository (vs per-server)
* Syncronization of the Git-tags was removed because GitLab loves to block tag's deletion.
* Single non-bare Git repositories is used for the synchronization.
* You can attach some your automations and notify somehow about conflict solving or about any branch deletion.
* others.

## The Glossary

My [glossary](http://blog.it3xl.com/2018/02/glossary-of-synchronization-of-remote.html) related to the topic.

## How to Use

You need to describe the prefixes and simple details of your real remote repositories in a simple config-file.<br/>
Create the same file as [your_repo_some_name.sh](https://github.com/it3xl/git-sync/blob/master/repo_settings/sample_repo.sh) and put it next to it.

Run the **git-sync** and pass the name of your config file as a parameter.<br/>
Run **git-sync** so periodically, better once in a minute.

That's all. You may work and forget about **git-sync**.<br/>
In the case of any synchronization interruption the **git-sync** will do everything right.

### Prepare Environment

Use any \*nix or Window machine.

Install Git

For \*nix users - update you bash and awk to any modern version

Tune any automation to invocate **git-sync** periodically - crons, schedulers, etc.

### Invocation

Run in a console

    bash git-sync.sh your_file_with_project_settings.sh

Repeat this invocation when you want to synchronize your remote repositories.



