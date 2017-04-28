{-# LANGUAGE OverloadedStrings #-}

import qualified Data.Foldable    as F
import qualified Data.Text        as T
import qualified Data.Text.IO     as IO
import qualified System.Directory as D
import qualified System.Exit      as E
import           System.IO
import qualified System.Posix     as P
import           System.Process

-- HEREDOC might be nicer... might...
headers :: T.Text -> [ T.Text ]
headers version =
  [ "      ___         ___           ___                       ___           ___                       ___     ",
    "     /  /\\       /  /\\         /  /\\          ___        /  /\\         /  /\\        ___          /  /\\    ",
    "    /  /:/_     /  /::\\       /  /:/         /  /\\      /  /::\\       /  /::\\      /  /\\        /  /::\\   ",
    "   /  /:/ /\\   /  /:/\\:\\     /  /:/         /  /:/     /  /:/\\:\\     /  /:/\\:\\    /  /:/       /  /:/\\:\\  ",
    "  /  /:/ /:/  /  /:/~/::\\   /  /:/  ___    /  /:/     /  /:/  \\:\\   /  /:/~/:/   /__/::\\      /  /:/  \\:\\ ",
    " /__/:/ /:/  /__/:/ /:/\\:\\ /__/:/  /  /\\  /  /::\\    /__/:/ \\__\\:\\ /__/:/ /:/___ \\__\\/\\:\\__  /__/:/ \\__\\:\\",
    " \\  \\:\\/:/   \\  \\:\\/:/__\\/ \\  \\:\\ /  /:/ /__/:/\\:\\   \\  \\:\\ /  /:/ \\  \\:\\/:::::/    \\  \\:\\/\\ \\  \\:\\ /  /:/",
    "  \\  \\::/     \\  \\::/       \\  \\:\\  /:/  \\__\\/  \\:\\   \\  \\:\\  /:/   \\  \\::/~~~~      \\__\\::/  \\  \\:\\  /:/ ",
    "   \\  \\:\\      \\  \\:\\        \\  \\:\\/:/        \\  \\:\\   \\  \\:\\/:/     \\  \\:\\          /__/:/    \\  \\:\\/:/  ",
    "    \\  \\:\\      \\  \\:\\        \\  \\::/          \\__\\/    \\  \\::/       \\  \\:\\         \\__\\/      \\  \\::/   ",
    "     \\__\\/       \\__\\/         \\__\\/                     \\__\\/         \\__\\/                     \\__\\/    ",
    "",
    T.append (T.append "Staring version " version) "...",
    "" ]


showHeader :: IO ()
showHeader = do
    version <- IO.readFile "factorio.version"
    sequence_ (fmap IO.putStrLn (headers (T.init version)))

envVarsWithDefaults :: [ (T.Text, T.Text) ]
envVarsWithDefaults =
    [   ("FACTORIO_TAGS",                           "[]"            ),
        ("FACTORIO_MAX_PLAYERS",                    "0"             ),
        ("FACTORIO_VISIBILITY_PUBLIC",              "false"         ),
        ("FACTORIO_VISIBILITY_LAN",                 "false"         ),
        ("FACTORIO_CREDENTIALS_USERNAME",           ""              ),
        ("FACTORIO_CREDENTIALS_PASSWORD",           ""              ),
        ("FACTORIO_GAME_PASSWORD",                  ""              ),
        ("FACTORIO_REQUIRE_VERIFICATION",           "true"          ),
        ("FACTORIO_MAX_UPLOAD_KBPS",                "0"             ),
        ("FACTORIO_MIN_LATENCY_TICKS",              "0"             ),
        ("FACTORIO_IGNORE_PLAYER_LIMIT_RETURNING",  "false"         ),
        ("FACTORIO_ALLOW_COMMANDS",                 "admins-only"   ),
        ("FACTORIO_AUTOSAVE_INTERVAL",              "10"            ),
        ("FACTORIO_AUTOSAVE_SLOTS",                 "5"             ),
        ("FACTORIO_AUTOKICK_INTERVAL",              "0"             ),
        ("FACTORIO_AUTO_PAUSE",                     "true"          ),
        ("FACTORIO_ONLY_ADMINS_CAN_PAUSE",          "true"          ),
        ("FACTORIO_AUTOSAVE_ONLY_ON_SERVER",        "true"          ),
        ("FACTORIO_ADMINS",                         "[]"            ) ]

getEnvOrDefault :: (T.Text, T.Text) -> IO String
getEnvOrDefault tuple = P.getEnvDefault (T.unpack (fst tuple)) (T.unpack(snd tuple))

withEnvVar :: (T.Text, T.Text) -> IO (T.Text, T.Text)
withEnvVar tuple = fmap (\x -> (fst tuple, T.pack x)) (getEnvOrDefault tuple)

ioEnvVars :: IO [ (T.Text, T.Text) ]
ioEnvVars = traverse withEnvVar envVarsWithDefaults

replaceVar :: T.Text -> (T.Text, T.Text) -> T.Text
replaceVar file tuple = T.replace (T.append "$" (fst tuple)) (snd tuple) file

parseVarsInFile :: T.Text -> [(T.Text, T.Text)] -> T.Text
parseVarsInFile = F.foldl replaceVar

factorioBasedir :: String
factorioBasedir = "/opt/factorio"

factorioBinary :: String
factorioBinary = factorioBasedir ++ "/bin/x64/factorio"

factorioSettingsFile :: String
factorioSettingsFile = factorioBasedir ++ "/server-settings.json"

factorioSaveGameFile :: String
factorioSaveGameFile = factorioBasedir ++ "/saves/save.zip"

factorioGameArgs :: [ String ]
factorioGameArgs = [ "--server-settings", factorioSettingsFile, "--start-server", factorioSaveGameFile ]
-- factorioGameArgs False = [ "--server-settings", factorioSettingsFile, "--start-server", factorioSaveGameFile ]

createSave :: Bool -> IO ()
createSave True  = return ()
createSave False = runSystemCommand factorioBinary [ "--create", factorioSaveGameFile ]

debugMode :: Bool
debugMode = False

runSystemCommand :: String -> [ String ] -> IO ()
runSystemCommand command args =
    if debugMode
        then do
            (_, _, _, processHandle) <- createProcess (proc "echo" args)
                { std_in  = UseHandle System.IO.stdin, std_err = UseHandle System.IO.stderr }
            waitForProcess processHandle
            return ()
        else do
            (_, _, _, processHandle) <- createProcess (proc command args)
                { std_in  = UseHandle System.IO.stdin, std_err = UseHandle System.IO.stderr }
            waitForProcess processHandle
            return ()

main :: IO ()
main = do
    showHeader
    varsToReplace <- ioEnvVars
    file <- IO.readFile "server-settings.template.json"
    IO.writeFile "server-settings.json" (parseVarsInFile file varsToReplace)
    saveExists <- D.doesFileExist factorioSaveGameFile
    createSave saveExists
    runSystemCommand factorioBinary factorioGameArgs
    return ()
