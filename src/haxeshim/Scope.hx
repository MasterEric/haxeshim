package haxeshim;
import haxe.DynamicAccess;

using sys.io.File;
using sys.FileSystem;
using haxe.io.Path;

typedef SeekingOptions = {
  var startLookingIn(default, null):String;
  var haxeshimRoot(default, null):String;
}

class Scope {
  
  static var IS_WINDOWS = Sys.systemName() == 'Windows';
  static var EXT = if (IS_WINDOWS) '.exe' else '';
  static var CONFIG_FILE = '.haxerc';
  /**
   * The root directory for haxeshim as configured when the scope was creates
   */
  public var haxeshimRoot(default, null):String;
  /**
   * Indicates whether the scope is global
   */
  public var isGlobal(default, null):Bool;
  /**
   * The directory of the scope, where the `.haxerc` file was found and also where the `.scopedHaxeLibs` directory is expected
   */
  public var scopeDir(default, null):String;
  /**
   * Indicates the path the the scope's config file. This is likely to be `'$scopeDir/.haxerc'`, 
   * but you should rely on this field to avoid hardcoding assumptions that may break in the future.
   */
  public var configFile(default, null):String;
  /**
   * The working directory that the scope was created with.
   * If the scope is not global, this is almost certainly a subdirectory of `scopeDir`.
   */
  public var cwd(default, null):String;
  
  /**
   * The data read from the config file.
   */
  public var config(default, null):Config;
  
  var resolver:Resolver;
  
  function new(haxeshimRoot, isGlobal, scopeDir, cwd) {
    
    this.haxeshimRoot = haxeshimRoot;
    this.isGlobal = isGlobal;
    this.scopeDir = scopeDir;
    this.cwd = cwd;
    
    configFile = '$scopeDir/$CONFIG_FILE';

    //trace(file);
    var src = 
      try {
        configFile.getContent();
      }
      catch (e:Dynamic) {
        throw 'Unable to open file $configFile because $e';
      }
    
    this.config =
      try {
        haxe.Json.parse(src);
      }
      catch (e:Dynamic) {
        Sys.stderr().writeString('Invalid JSON in file $configFile:\n\n$src\n\n');
        throw e;
      }
      
    if (config.version == null)
      throw 'No version set in $configFile';
      
    switch config.resolveLibs {
      case Scoped | Mixed | Haxelib:
      case v:
        throw 'invalid value $v for `resolveLibs` in $configFile';
    }
    
    this.resolver = new Resolver(cwd, scopeDir, config.resolveLibs, ['HAXESHIM_LIBCACHE' => '$haxeshimRoot/libs']);
    
  }
  
  function resolveThroughHaxelib(libs:Array<String>) {
    //TODO: this is currently a dummy implementation
    var ret = [];
    
    for (l in libs) {
      ret.push('-lib');
      ret.push(l);
    }
    
    return ret;
  }
  
  public function resolve(args:Array<String>) 
    return resolver.resolve(args, resolveThroughHaxelib);
    
  public function runHaxe(args:Array<String>) {
    trace(resolve(args));
    //return Exec.run('$haxeRoot/versions/${config.version}/', workingDir, 
  }  
  
  static public function seek(options:SeekingOptions, ?cwd) {
    
    if (cwd == null)
      cwd = options.startLookingIn;
    
    var make = Scope.new.bind(options.haxeshimRoot, _, _, cwd);
      
    function global()
      return make(true, options.haxeshimRoot);
      
    function dig(cur:String) 
      return
        switch cur {
          case '$_/$CONFIG_FILE'.exists() => true:
            make(false, cur);
          case '/' | '':
            global();
          case _.split(':') => [drive, ''] if (IS_WINDOWS && drive.length == 1):
            global();
          default:
            dig(cur.directory().removeTrailingSlashes());
        }
        
    return dig(options.startLookingIn.absolutePath().removeTrailingSlashes());
  }
  
  static public var DEFAULT_HOME(default, null):String =
    if (IS_WINDOWS) 
      Sys.getEnv('APPDATA') + '/haxe';
    else 
      '~/haxe';//no idea if this will actually work
}