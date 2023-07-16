# TL;DR

This fork customizes Yubikey provisioning scripts for password-store and defn.

These instructions reset the openpgp app on the Yubikey.  Ensure only one yubikey is inserted or a random key may get deleted.

This section was tested on macOS.

### Setup

Install `ykman` with Homebrew.  Use the flake in this repo.

Change to the password-store and get the serial of the yubikey.  Repeat for each Yubikey.
```
cd ~/.password-store
serial="$(ykman list  | awk '{print $NF}')"
```

Set the domain of the gpg identities.
```
domain=defn.sh
```

### Delete old keys

Delete gpg keys with the same email of the gpg identity.  The identity email is formatted `yk-$serial@$domain`

Run these commands repeatedly until identities are no longer found.
```
gpg --batch --delete-secret-key "$(gpg --list-secret-keys yk-$serial@$domain  | grep 'fingerprint' | cut -d= -f2- | sed 's# ##g')"
gpg --batch --delete-key "$(gpg --list-keys yk-$serial@$domain  | grep 'fingerprint' | cut -d= -f2- | sed 's# ##g')"
```

### Reset Yubikey

Reset the opengpg app on the Yubikey.  Be generous with PIN retries to avoid resetting the key.
```
ykman --device "$serial" openpgp reset
ykman --device "$serial" openpgp access set-retries --force --admin-pin 12345678 99 99 99
```

### Provision Yubikey

Provision the Yubikey with custom PINs, gpg identity, and generate a gpg key that will be moved to the Yubikey.
```
yubikey_provision.sh --first-name defn --last-name Nghiem --email "yk-$serial@$domain" --current-admin-pin 12345678 --user-pin x --admin-pin x --yes
```

Check that the secet keys in gpg have been moved to the Yubikey.  They show up with `ssb>`.  That `>` means the local secret keys are stubs and don't contain any secrets; we want the secrets to be on the Yubikey.
```
gpg --list-secret-keys yk-$serial@$domain
```

### Backup GPG files

Copy the trustdb and pubring files to password-store.  These contain the public and private keys to initialize new gpg setups.
```
cp ~/.gnupg/trustdb.gpg ~/.gnupg/pubring.kbx ~/.password-store/config/gnupg-config/
```

### Publishing GPG keys
Publish public GPG keys to Ubuntu's keyserver for ease of sharing.

Make sure `dirnmgr` is running with a socket in daemon mode.

```
dirnmgr --daemon
```

This will publish all your keys.

```
gpg --list-keys | grep '^pub' | awk '{print $2}' | cut -d/ -f2 | runmany 'gpg --keyserver keyserver.ubuntu.com --send-key $1'
```

## Configure password-store

Add the gpg identity to password-store so new passwords are encrypted for the new identity.
```
echo "yk-$serial@$domain" >> ~/.password-store/.gpg-id
```

Re-encrypt the password store for all identities.
```
pass init $(cat .gpg-id)
```

# Paper Key

To generate a paper gpg key, omit the curent admin PIN.
```
yubikey_provision.sh --first-name defn --last-name Nghiem --email "something-something@$domain" --yes
```

Then export the secret to a file.
```
gpg --export-secret-key -a --export-options export-backup KEY_ID
```

# Yubikey provisioning scripts

See https://github.com/santiago-mooser/yubikey-provisioning-scripts for upstream documentation, which may not be synced with this fork.

## Authors

Santiago Espinosa Mooser - (yps@santiago-mooser.com)
Cuong Nghiem - (iam@defn.sh)
