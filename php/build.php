<?php


/**
 * @param float $seconds
 */
function wait($seconds = 0.10)
{
	usleep(($seconds) * 1000000);
}

/**
 * @param $dir
 * @param string $pattern
 */
function removeFilesFromDir($dir, $pattern = '~[A-z0-9-_]+\.xml$~')
{
	if ($dh = opendir($dir)) {
		while (($fileName = readdir($dh)) !== false) {
			if (is_file($file = $dir . $fileName)) {
				if (preg_match($pattern, $fileName)) {
					echo 'remove file:' . $fileName . chr(10);
					unlink($file);
					wait();
				}
			}
		}

	}
}

/**
 * @param $dir
 * @param $targetDir
 * @param $rootNode
 * @param $isPatchFile
 */
function buildFilesFromDir($dir, $targetDir, $rootNode, $isPatchFile = false)
{
	$outFiles = array();
	if ($dh = opendir($dir)) {
		while (($fileName = readdir($dh)) !== false) {
			if (is_file($file = $dir . $fileName)) {
				$fileInfo = pathinfo($file);
				if ($fileInfo['extension'] == 'xml') {
					list($extension, $targetFileName) = preg_split('~[@]~', $fileName);
					if (!($outFiles[$targetFileName])) {
						$outFiles[$targetFileName] = array();
					}
					/**
					 * @var SimpleXMLElement $singleDoc
					 */
					$xml = getFileContent($file);

					$xml = preg_replace('~(^[ ]{1,}|[ ]{1,}$)~msi', '', $xml);
					$xml = preg_replace('~[\n|\r|\t]~i', '', $xml);
					$xml = preg_replace('/<!--(.|\s)*?-->/', '', $xml);

					if ($singleDoc = simplexml_load_string($xml)) {
						echo "process file: " . $file . "\n";
						wait();
						/**
						 * @var SimpleXMLElement $diffChildNode
						 */
						$outFiles[$targetFileName][] = "\n" . '<!-- Source: ' . $extension . ' -->';
						foreach ($singleDoc->children() as $diffChildNode) {
							$outFiles[$targetFileName][] = $diffChildNode->asXML();
						}
					}
				}
			}
		}
	}

	/**
	 * @var SimpleXMLElement $xmlNode
	 */
	foreach ($outFiles as $targetFileName => $aXmlContents) {
		$dom = new DOMDocument('1.0', 'utf-8');
		$dom->preserveWhiteSpace = false;
		$dom->formatOutput = true;
		$dom->loadXML('<' . $rootNode . '>' . implode('', $aXmlContents) . '</' . $rootNode . '>');
		$formattedContent = $dom->saveXML();
		setFileContent($targetDir . ($isPatchFile ? 'Patch_' : '') . $targetFileName, $formattedContent);
	}
}

/**
 * @param $file
 * @param $content
 */
function setFileContent($file, $content)
{
	if ($fp = fopen($file, 'w')) {
		fwrite($fp, $content);
		fclose($fp);
	}
}

/**
 * @param $file
 * @return bool|string
 */
function getFileContent($file)
{
	$content = '';
	if ($fp = fopen($file, 'r')) {
		$content = fread($fp, filesize($file));
		fclose($fp);
	}
	return $content;
}

/**
 * @param string $rootNode
 * @param string $currentDir
 * @param string $targetDir
 * @param bool $isPatchFile
 */
function build($rootNode, $currentDir, $targetDir, $isPatchFile = false)
{
	echo "process folder: " . $targetDir . "\n";
	wait();
	removeFilesFromDir($targetDir);
	buildFilesFromDir($currentDir, $targetDir, $rootNode, $isPatchFile);
}