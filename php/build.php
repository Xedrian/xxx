<?php

/**
 * @param string $rootNode
 * @param string $currentDir
 * @param string $targetDir
 */
function build($rootNode, $currentDir, $targetDir)
{
    function wait($seconds = 0.25)
    {
        usleep(($seconds) * 1000000);
    }

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

    function buildFilesFromDir($dir, $targetDir, $rootNode)
    {

        $outFiles = array();

        if ($dh = opendir($dir)) {
            while (($fileName = readdir($dh)) !== false) {
                if (is_file($file = $dir . $fileName)) {
                    $fileInfo = pathinfo($file);
                    if ($fileInfo['extension'] == 'xml') {
                        list(, $targetFileName) = preg_split('~[@]~', $fileName);
                        if (!($outFiles[$targetFileName])) {
                            $outFiles[$targetFileName] = array();
                        }
                        /**
                         * @var SimpleXMLElement $singleDoc
                         */
                        if ($singleDoc = simplexml_load_file($file)) {
                            /**
                             * @var SimpleXMLElement $diffChildNode
                             */
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
            $xml = new SimpleXMLElement('<' . $rootNode . '>' . implode(chr(10), $aXmlContents) . '</' . $rootNode . '>');
            $xml->asXML($targetDir . $targetFileName);

        }
    }

    function getFileContent($file)
    {
        $content = '';
        if ($fp = fopen($file, 'r')) {
            $content = fread($fp, filesize($file));
            fclose($fp);
        }
        return $content;
    }

    #$currentDir = dirname(__FILE__) . '/';


    removeFilesFromDir($targetDir);
    buildFilesFromDir($currentDir, $targetDir, $rootNode);


    echo "### finished ###";
    #sleep(5);
}