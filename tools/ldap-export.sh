#!/bin/sh
#============================================================================
# $Id: ldap-export.sh,v 1.1 2008/08/08 01:31:42 akaufman Exp $
#
# Example script to extract data from an LDAP repository
#============================================================================
OUTPUT=export.ldif
SEARCHBASE=ou=people,dc=example,dc=com
LDAPURI=ldap://directory.example.com
/usr/bin/ldapsearch -x -LLL -H ${LDAPURI} -b ${SEARCHBASE} "(objectClass=inetOrgPerson)" > ${OUTPUT}