<?php
/******************************************/
// db_utf8_fix.php                        //
// Author: J. van Hemert                  //
// Date: 26-10-2011                       //
//                                        //
// Fixes encoding when utf-8-encoded data //
// is stored in tables with other (e.g.   // 
// latin_swedish_ci) encoding.            //
// Will convert all columns in all tables //
// to utf8_general_ci.                    //
// Run from fileadmin folder in TYPO3     //
// installation.                          //
/******************************************/

	//Set to TRUE to generate an enormous amount of debug output with
	//analysis of table structure.
define('DEBUG', FALSE);
	//Set to FALSE to really convert the database
define('SIMULATE', TRUE);


require_once ('../typo3conf/localconf.php');

echo str_repeat(' ', 256);
?>
<html>
<head>
<style type="text/css">
  .normal {
    color: black;
  }
  .okay {
    color: green;
  }
  .label {
    color: blue;
  }
  .error {
    color: red;
  }
</style>
</head>
<body>
<?php

$tables = array();
$typeconv = array(
	'char' => 'binary',
	'text' => 'blob',
);
$db = mysql_connect($typo_db_host, $typo_db_username, $typo_db_password, TRUE);
if (!is_resource($db)) {
	die('Could not connect to db!: ' . mysql_error());
}
if (mysql_select_db($typo_db, $db) === FALSE) {
	die('Could not select database!: ' . mysql_error());
}

	// Collect table names
$sql = 'SHOW TABLES;';
$db_res = mysql_query($sql, $db);
if (!is_resource($db_res)) {
	die ('Could not get query result!: ' . mysql_error() . "\n" . $sql);
}
while ($row = mysql_fetch_array($db_res, MYSQL_NUM)) {
	if (DEBUG) {
		var_dump($row);
	}
	$tables[] = $row[0];
}

	// process each table
foreach ($tables as $table) {
	echo '<div><span class="label">' . $table . ': </span><span class="normal">';
		// Collect column information
	$sql = 'SHOW FULL COLUMNS FROM `' . $table . '`;';
	$db_res = mysql_query($sql, $db);
	if (!is_resource($db_res)) {
		die ('Could not get table data!: ' . mysql_error() . "\n" . $sql);
	}
	$columns = array();
	while ($row = mysql_fetch_assoc($db_res)) {
		if (DEBUG) {
			echo 'column: ';
			var_dump($row);
		}
		$columns[] = $row;
	}
		// process each column
	foreach ($columns as $column) {
		set_time_limit(60);
		$oldtype = $column['Type'];
		if (DEBUG) {
			echo 'Original: ' . $column['Type'] . "\n";
		}
			// modify type into a binary equivalent
		$column['Type'] = str_replace(array_keys($typeconv), array_values($typeconv), $column['Type']);
		if (DEBUG) {
			echo 'modified: ' . $column['Type'] . "\n";
		}
			// only do the magic if the type was modified
		if ($column['Type'] != $oldtype) {
			$column['Null'] = (strtolower($column['Null']) == 'yes') ? 'NULL' : 'NOT NULL';
			$column['Default'] = (is_numeric($column['Default']))
					? $column['Default']
					: ($column['Default'] === 'NULL') ? $column['Default'] : '\'' . $column['Default'] . '\'';
			$sql = 'ALTER TABLE `' . $table . '` MODIFY COLUMN `' . $column['Field'] . '` ' . $column['Type'] . ' ' . $column['Null'];
				// only use default part if it's not a blob/text
			if (strpos($column['Type'], 'blob') === FALSE) {
				$sql .= ' DEFAULT ' . $column['Default'];
			}
			$sql .= ' ' . $column['Extra'] . ';';
			if (DEBUG) {
				echo $sql . "\n";
			} else {
				if (!SIMULATE) {
					$db_res = mysql_query($sql, $db);
					if (!is_resource($db_res) && mysql_errno($db) != 0) {
						echo 'Could not execute query!: ' . mysql_error($db) . "\n" . $sql;
					}
				}
			}
				// modify type back to the non-binary equivalent, but add utf8 character set / collation setting
			$column['Type'] = str_replace(array_values($typeconv), array_keys($typeconv), $column['Type']);
			$sql = 'ALTER TABLE `' . $table . '` MODIFY COLUMN `' . $column['Field'] . '` ' . $column['Type'] .
				   ' CHARACTER SET utf8 COLLATE utf8_general_ci ' . $column['Null'];
			if (strpos($column['Type'], 'text') === FALSE) {
				$sql .= ' DEFAULT ' . $column['Default'];
			}
			$sql .= ' ' . $column['Extra'] . ';';
			if (DEBUG) {
				echo $sql . "\n";
			} else {
				if (!SIMULATE) {
					$db_res = mysql_query($sql, $db);
					if (!is_resource($db_res) && mysql_errno($db) != 0) {
						echo 'Could not execute query!: ' . mysql_error($db) . "\n" . $sql;
					}
				}
				echo '.';
				flush();
			}
		}
	}

		// set defaults for table to utf8
	$sql = 'ALTER TABLE `' . $table . '` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;';
	if (DEBUG) {
		echo $sql . "\n";
	} else {
		if (!SIMULATE) {
			$db_res = mysql_query($sql, $db);
			if (!is_resource($db_res) && mysql_errno($db) != 0) {
				echo 'Could not execute query!: ' . mysql_error($db) . "\n" . $sql;
			}
		}
		echo '</span><span class="okay"> OK</span></div>';
		flush();
	}

}
	// set defaults for database to utf8
echo '<div><span class="label">DATABASE: </span><span class="normal">';
$sql = 'ALTER DATABASE `' . $typo_db . '` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;';
if (DEBUG) {
	echo $sql . "\n";
} else {
	if (!SIMULATE) {
		$db_res = mysql_query($sql, $db);
		if (!is_resource($db_res) && mysql_errno($db) != 0) {
			echo 'Could not execute query!: ' . mysql_error($db) . "\n" . $sql;
		}
	}
	echo '</span><span class="okay"> OK</span></div>';
	flush();
}

echo '<div>finished converting tables</div>';
mysql_close($db);
?>
</body>
</html>