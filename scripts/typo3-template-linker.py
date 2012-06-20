#!/usr/bin/env python

# vim: et ts=4 sts=4 sw=4 tw=80

import sys
import os.path
import md5

def main():
	"""
	Link files in uploads/tx_ttnews to files in bpminstitute.org with
	the same md5sum.

	Reason is that tt_news creates a copy of the template for every
	use of the plugin and that makes managing this stuff impossible.
	"""

	# change to directory passed on the command line
	if len(sys.argv) < 2:
		usage()
		sys.exit(1)
	if sys.argv[1] in ('--help', '-help', '-h'):
		usage()
		sys.exit(1)
	if not os.path.isdir(sys.argv[1]):
		print "Error: %s is not a directory. Try %s --help for usage." % (sys.argv[1], sys.argv[0])
		sys.exit(1)
	olddir = os.getcwd()
	os.chdir(os.path.join(sys.argv[1], 'fileadmin'))
	
	# check existance of uploads/tx_ttnews
	if not os.path.isdir('bpminstitute.org'):
		print """Error: directory %s does not exist. Try %s --help for usage.""" % (
			os.path.join(sys.argv[1], 'fileadmin/bpminstitute.org'), sys.argv[0])
		sys.exit(1)

	# check existance of fileadmin/bpminstitute.org
	if not os.path.isdir('uploads/tx_ttnews'):
		print """Error: directory %s does not exist. Try %s --help for usage.""" % (
			os.path.join(sys.argv[1], 'uploads/tx_ttnews'), sys.argv[0])
		sys.exit(1)

	# build dict {md5sum: filename} for bpminstitute.org
	os.chdir('bpminstitute.org')
	md5sums = {}
	for entry in os.listdir('.'):
		if os.path.islink(entry):
			continue
		if not os.path.isfile(entry):
			continue
		# skip cvs conflict files
		if entry.startswith('.#'):
			continue
		md5sum = md5.new(file(entry).read()).hexdigest()
		if md5sums.has_key(md5sum):
			print "Duplicate file in bpminstitute.org:\n%s and %s" % (
				md5sums[md5sum], entry)
			md5sums[md5sum].append(entry)
		else:
			md5sums[md5sum] = [entry]
		
	# do the linking
	os.chdir(os.path.join('..', 'uploads/tx_ttnews'))
	for entry in os.listdir('.'):
		# skip files that are links already
		if os.path.islink(entry):
			continue
		# skip directories, pipes, sockets..
		if not os.path.isfile(entry):
			continue

		md5sum = md5.new(file(entry).read()).hexdigest()
		if not md5sums.has_key(md5sum):
			print "File without duplicate in bpminstitute.org: %s" % (
				os.path.join(sys.argv[1], 'uploads/tx_ttnews', entry))
			continue

		# find the filename with the longest common prefix with the file to link
		# among the files to link to

		# for example there exist bpmi.org/news_template.conference.tmpl and
		# bpmi.org/news_template.presentation.tmpl . This makes sure that
		# news_template.presentation_01.tmpl gets linked to
		# news_template.presentation.tmpl and not to
		# news_template.conference.tmpl

		whereto = None
		commonprefixlength = -1
		for f in md5sums[md5sum]:
			cpl = os.path.commonprefix((f, entry))
			if cpl > commonprefixlength:
				commonprefixlength = cpl
				whereto = f

		print "ln -sf ../../bpminstitute.org/%s %s" % (
			whereto, entry)

def usage():
	print """%s: link duplicate tt_news templates.
Usage: %s DIRECTORY

DIRECTORY must contain the folders uploads/tx_ttnews and fileadmin/bpminstitute.

Example:
	%s /home/dev4/public_html/bpminstitute
""" % ((sys.argv[0],) * 3)

if __name__ == '__main__':
	main()