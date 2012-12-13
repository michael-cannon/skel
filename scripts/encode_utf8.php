#!/opt/local/bin/php -q
<?php
/**
 * Convert UTF8 characters to Unicode
 *
 * @ref http://stackoverflow.com/questions/7608643/how-to-convert-utf8-characters-to-numeric-character-entities-in-php
 * @author Michael Cannon <mc@aihr.us>
 */

// $argv argument values
// $argc argument values count

echo "\n";

if ( 1 == $argc )
	die( "Need file name\n" );

$file_name						= $argv[ 1 ];
$orig_file						= file_get_contents( $file_name );

$conv_map						= array( 0x80, 0xffff, 0, 0xffff );
$conv_file						= mb_encode_numericentity( $orig_file, $conv_map, 'UTF-8' );

if ( isset( $argv[ 2 ] ) )
	$file_dest					= $argv[ 2 ];
else
	$file_dest					= $file_name . '.conv';

$fh								= fopen( $file_dest, 'w+' );
$file_write						= fwrite( $fh, $conv_file );

if ( $file_write )
	die( "File {$file_dest} written" );
else
	die( "File {$file_dest} failed to be written" );

echo "\n";

?>