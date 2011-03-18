#!/usr/bin/env ruby

require "rexml/document"

def print_macro_string(name, value)
  print "\n#define " + name + ' "' + "#{value}" + '"' +  "\n"
  
end


def print_macro_int(name, value)
  print "\n#define " + name + ' ' + "#{value}\n"
  
end

class Service
  def initialize
    @serviceList = Array.new
  end

  def get_varcount_macro_name
    return get_simple_name.upcase  + '_VARCOUNT'
  end
  def get_macro_name
    return "SERVICE_" + get_simple_name.upcase
  end

  def get_simple_name
    if /service:(.+?):/ =~ serviceType
      return $1
    end
    return ""
  end

  attr_accessor :serviceType
  attr_accessor :serviceId
  attr_accessor :controlURL
  attr_accessor :eventSubURL
  attr_accessor :SCPDURL
  attr_accessor :SCPD

  def to_s

    print '  ' +  @serviceType + "\n"
    print '  ' +  @serviceId + "\n"
    print '  ' +  @controlURL + "\n"
    print '  ' +  @eventSubURL + "\n"
    print '  ' +  @SCPDURL + "\n"
    @SCPD.to_s
  end

end

class Device
  attr_accessor :deviceType
  attr_accessor :friendlyName
  attr_accessor :manufacturer
  attr_accessor :manufacturerURL
  attr_accessor :modelDescription
  attr_accessor :modelName
  attr_accessor :modelNumber
  attr_accessor :modelURL
  attr_accessor :serialNumber
  attr_accessor :UDN
  attr_accessor :UPC
  attr_accessor :serviceList
  attr_accessor :presentationURL

  def initialize
    @serviceList = Array.new
  end

  def to_s
    print @deviceType + "\n"
    print @friendlyName + "\n"
    print @manufacturer + "\n"
    print @manufacturerURL + "\n"
    print @modelDescription + "\n"
    print @modelName + "\n"
    print @modelNumber + "\n"
    print @modelURL + "\n"
    print @serialNumber + "\n"
    print @UDN + "\n"
    print @UPC + "\n"
    serviceList.each{ |s|
      s.to_s

    }
    print @presentationURL + "\n"
  end
end


class SCPD
  attr_accessor :actionList
  attr_accessor :serviceStateTable
  def initialize
    @actionList = Array.new
    @serviceStateTable = Hash.new
  end
  def to_s
    @actionList.each{ |e|
      e.to_s
    }

    @serviceStateTable.each{|k,e|
      e.to_s
    }
  end



end

class Action 
  attr_accessor :name
# retval は argumentList にふくめない
  attr_accessor :argumentList
  attr_accessor :retval
  def initialize
    @argumentList = Array.new
  end

  def to_s
    print "    "  + @name + "\n"
    @argumentList.each{ |e|
      e.to_s
    }
    if @retval
      print "    retval\n"
      @retval.to_s
    end
  end
end

class Argument
  attr_accessor :retval
  attr_accessor :name
  attr_accessor :related
  attr_accessor :direction
  def initialize
    @retval = false
  end

  def to_s
    print "      " + @name+ "\n"
    print "      #{@retval}" + "\n"
    print  "      " + @related.name + "\n"
    print  "      " + @direction + "\n"
  end
end

class AllowedValueRange
  attr_accessor :minimum
  attr_accessor :maximum
  attr_accessor :step
  def to_s
# ほんとは 全部あるかわからんぜ?
    print "        " + @minimum + "\n"
    print "        " + @maximum+ "\n"
    print "        " + @step+ "\n"
  end

end

class StateVariable
  attr_accessor :sendEvents
  attr_accessor :name
  attr_accessor :dataType
  attr_accessor :allowedValueRange
  attr_accessor :defaultValue
  def initialize
  end

  def int_p
    case @dataType
    when 'i4'
      return true
    when 'Boolean'
      return false
    end
    return nil
  end

  def get_c_type
    case @dataType
    when 'i4'
#ほんとは ちゃんと 4byteの型を指定するべき
      return 'int'
    when 'Boolean'
      return 'int'
    end
    return nil
  end

  def to_s
    print "      " + @name+ "\n"
    print "      #{@sendEvents}"  + "\n"
    print "      " + @dataType+ "\n"
    if @allowedValueRange
      @allowedValueRange.to_s
    end
    print "      " + @defaultValue+ "\n"
  end
end


def parseScpdFile(filename)
  scpd = SCPD.new
  scpd_doc = REXML::Document.new( File.new(filename))
  
  root = scpd_doc.root 

  elements = root.elements[1, 'serviceStateTable']
  if elements

    elements.each_element("stateVariable") {|elm|  
      var = StateVariable.new
      if 'yes' == elm.attributes['sendEvents']
	var.sendEvents = true
      else
	var.sendEvents = false
      end
      elm.each_element("*"){ |el|
	case el.name
	when 'name'
	  var.name = el.text
	when 'dataType'
	  var.dataType = el.text
	when 'allowedValueRange'
	  range = AllowedValueRange.new
	  el.each_element("*"){ |e|	
	    case e.name
	    when 'minimum'
	      range.minimum = e.text
	    when 'maximum'
	      range.maximum = e.text
	    when 'step'
	      range.step = e.text
	    end
	  }
	  var.allowedValueRange = range
	when 'defaultValue'
	  var.defaultValue = el.text
	end
      }
      scpd.serviceStateTable[var.name] = var
    }
  end

  elements = root.elements[1, 'actionList']
  if elements
    elements.each_element("action"){ |elm|
      action = Action.new
      elm.each_element("*"){ |el|
	case el.name
	when 'name'
	  action.name = el.text
	when 'argumentList'
	  el.each_element("argument"){ |e2|
	    arg = Argument.new
	    e2.each_element("*"){ |e|
	      case e.name
	      when 'retval'
		arg.retval = true
	      when 'name'
		arg.name = e.text
	      when 'relatedStateVariable'
		arg.related = scpd.serviceStateTable[e.text]
		unless arg.related
		  $stderr.print "Error: relatedStateVariable is not found\n"
		  exit
		end
	      when 'direction'
		arg.direction = e.text
	      end
	    }
	    if arg.retval
	      if action.retval
		$stderr.print "Error: double definitions of retval\n"
		exit
	      end
	      action.retval = arg
	    else
	      action.argumentList << arg
	    end
	  }
	end
	
      }
      scpd.actionList << action
    }

  end

  return scpd
end





# デバイスのパース
def parseDeviceFile(device_filename)

  file = File.new( device_filename)
  device_doc = REXML::Document.new( file )



  device = Device.new

  root = device_doc.root 

  elements = root.elements[1, 'device']

  if elements
    elements.each_element("*") {|elm|
      case  elm.name
      when 'deviceType'
	device.deviceType = elm.text
      when 'friendlyName'
	device.friendlyName = elm.text
      when 'manufacturer'
	device.manufacturer = elm.text
      when 'manufacturerURL'
	device.manufacturerURL = elm.text
      when 'modelDescription'
	device.modelDescription = elm.text
      when 'modelName'
	device.modelName = elm.text
      when 'modelNumber'
	device.modelNumber = elm.text
      when 'modelURL'
	device.modelURL = elm.text
      when 'serialNumber'
	device.serialNumber = elm.text
      when 'UDN'
	device.UDN = elm.text
      when 'UPC'
	device.UPC = elm.text
      when 'serviceList'
	elm.each_element('service'){ |el|
	  service = Service.new
	  el.each_element("*"){ |e|
	    case e.name
	    when 'serviceType'
	      service.serviceType = e.text
	    when 'serviceId'
	      service.serviceId = e.text
	    when 'controlURL'
	      service.controlURL = e.text
	    when 'eventSubURL'
	      service.eventSubURL = e.text
	    when 'SCPDURL'
	      service.SCPDURL = e.text
	      service.SCPD =  parseScpdFile(File.dirname(device_filename) + service.SCPDURL)
	      
	    end
	  }
	  device.serviceList <<  service
	  
	}
      when 'presentationURL'
	device.presentationURL = elm.text
      end
      
    }
  end

  return device

end





device = parseDeviceFile(ARGV[0])

#device.to_s

# upnp_device.c ファイルの出力


print <<EOS
#include <stdio.h>
#include <signal.h>

#include "ithread.h"
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "upnp.h"
#include <stdlib.h>
#include "upnptools.h"
#include "ixml.h"

#define DEFAULT_WEB_DIR "./web"

#define DEVICE_DESC_XML "devicedesc.xml"

#define DEFAULT_ADVR_EXPIRE  100

#define MAX_VAL_LEN 5

#ifndef NAME_SIZE
#define NAME_SIZE 256
#endif

#ifndef URL_SIZE
#define URL_SIZE 512
#endif

static int
DeviceSetServiceTableVar( unsigned int service,
                          unsigned int variable,
                          const unsigned char* value );

static unsigned char *
SampleUtil_GetFirstDocumentItem( IXML_Document * doc,
                                 const unsigned char *item );


EOS


max_var = 0
max_action = 0
serviceType = []
i = 0
device.serviceList.each { |service|
  
  serviceType << service.serviceType
  print_macro_int(service.get_macro_name, i)
  i+=1

    scpd = service.SCPD
    if scpd.serviceStateTable.size  > max_var
      max_var = scpd.serviceStateTable.size
    end

  print_macro_int(service.get_varcount_macro_name, scpd.serviceStateTable.size)

  var_number  = 0
    scpd.serviceStateTable.each{ |name, var| 

    print_macro_int(service.get_simple_name.upcase  + '_' +  name.upcase, var_number)
    var_number+=1

      if var.allowedValueRange

	print_macro_int(service.get_simple_name.upcase  + '_' +  name.upcase + "_MIN", var.allowedValueRange.minimum)
	print_macro_int(service.get_simple_name.upcase  + '_' +   name.upcase + "_MAX", var.allowedValueRange.maximum)
	print_macro_int(service.get_simple_name.upcase  + '_' +   name.upcase + "_STEP", var.allowedValueRange.step)
      end
    
    }
    
    if scpd.actionList.size  > max_action
      max_action = scpd.actionList.size
    end
    

}



print_macro_string('DEVICE_UDN',  device.UDN)

print_macro_int('MAX_VARS',  max_var)
print_macro_int('MAX_ACTIONS',  max_action)




print <<EOS

typedef int (*upnp_action) (IXML_Document *request, IXML_Document **out, 
 			    char **errorString);


//typedef struct {
//    unsigned char name[NAME_SIZE];
//    unsigned char type[NAME_SIZE];
//    int int_value;
    /*  unsigned char*  str_value */
//} state_variable;


typedef struct {
    unsigned char* name;
    upnp_action action;
}action;


typedef struct  {
    unsigned char serviceType[NAME_SIZE];
    unsigned char serviceId[NAME_SIZE];
    unsigned char** variableName;
    unsigned char variableStrValue[MAX_VARS][MAX_VAL_LEN];
    unsigned int  variableCount;
    action actions[MAX_ACTIONS];

} Service;

EOS

print_macro_int('SERVICE_COUNT',  device.serviceList.size)

print <<EOS

static Service serviceTable[SERVICE_COUNT];

EOS

# ServiceType いらないんじゃない?
print "static unsigned char* ServiceType[]  = {"
serviceType.each{ |s|
  print '"'
  print s
  print '", '

}

print "};\n\n"

device.serviceList.each { |service|
  var_name = []
  var_default =[]
  service.SCPD.serviceStateTable.each{ |name, var|   
    var_name << name
    var_default << var.defaultValue
  }
  

  print "static unsigned char* "
  print service.get_simple_name + "_varname[] = {"
  var_name.each{ |s|
    print '"'
    print s
    print '", '
  }
  print "};\n"
  
#  print "static unsigned char "
#  print service.get_simple_name + "_varval[#{service.get_simple_name.upcase  + '_VARCOUNT'}][MAX_VAL_LEN];\n"

  print "static unsigned char* "
  print service.get_simple_name + "_varval_def[] = {"
  var_default.each{ |s|
    print '"'
    print s
    print '", '
  }
  print "};\n\n"

}



print <<EOS

static UpnpDevice_Handle deviceHandle = -1;

static ithread_mutex_t DeviceMutex;
EOS


#TODO: 変数設定関数
service_number = 0
device.serviceList.each { |service|
var_number = 0  
  service.SCPD.serviceStateTable.each{ |name, var|

print <<EOS
static int
#{service.get_simple_name}_Set_#{name}
(
  const unsigned char* newValue
) {
EOS



if var.int_p
print <<EOS
    int intValue = strtol(newValue, (char **)NULL, 10);
EOS

if var.allowedValueRange
#TODO: step
print <<EOS

    if (intValue < #{var.allowedValueRange.minimum} || intValue > #{var.allowedValueRange.maximum}){
        return 0;
    }
    return DeviceSetServiceTableVar(#{service.get_macro_name},
				    #{service.get_simple_name.upcase  + '_' +  name.upcase}, 
                                    newValue);

EOS
end

else
# とりあえずBooleanのみ
print <<EOS
    int intValue = strtol(newValue, (char **)NULL, 10);

    if (intValue != 0 && intValue != 1){
      return 0;
    }else{
        return DeviceSetServiceTableVar(#{service.get_macro_name},
				    #{service.get_simple_name.upcase  + '_' +  name.upcase}, 
                                    newValue);
    }
EOS

end 


    	    
print <<EOS

    return UPNP_E_SUCCESS;
}

EOS
    var_number += 1
  }
  service_number += 1
}



#TODO: 引数や返り値の処理
#アクション処理関数

device.serviceList.each { |service|
	service.SCPD.actionList.each{ |action|
print <<EOS
static int
#{service.get_simple_name}_#{action.name}
(   IXML_Document * in,
    IXML_Document ** out,
    char **errorString )
{
EOS
action.argumentList.each{ |arg|
    print "    unsigned char* "      
    print arg.name
    print ";\n";
}    
#print "    unsigned char* "      
#print action.retval.name
#print ";\n";

print <<EOS
    ( *out ) = NULL;
    ( *errorString ) = NULL;
EOS

action.argumentList.each{ |arg|
print <<EOS

    if( !( #{arg.name} = SampleUtil_GetFirstDocumentItem( in, "#{arg.name}" ) ) ) {
         ( *errorString ) = "Invalid #{arg.name}";

EOS

action.argumentList.each{ |arg2|
    print "        free("      
    print arg2.name
    print ");\n";
}    

print <<EOS	  
        return UPNP_E_INVALID_PARAM;
    }
EOS
}


print <<EOS	  
//TODO: 実際の処理を書く
//      エラーで抜ける際には freeを忘れないように




EOS

print "//TODO: UpnpAddToActionResponseの最後の引数として実際の返り値を入れること\n"
print <<EOS
        if( UpnpAddToActionResponse( out, "#{action.name}",
				    ServiceType[#{service.get_macro_name}],
				      "#{action.retval.name}",
                                     "0"  ) != UPNP_E_SUCCESS ) {
            ( *out ) = NULL;
            ( *errorString ) = "Internal Error";
EOS

action.argumentList.each{ |arg2|
    print "        free("      
    print arg2.name
    print ");\n";
}    
print <<EOS
            return UPNP_E_INTERNAL_ERROR;
        }
EOS

action.argumentList.each{ |arg2|
    print "        free("      
    print arg2.name
    print ");\n";
}  
print <<EOS
    return UPNP_E_SUCCESS;
}
EOS
  }

}
# サービス構造体の初期化(アクションを除く)
print <<EOS
static int
InitializeService(Service* service, 
                  const unsigned char* serviceType,
		  const unsigned char* serviceId,
		  unsigned int count,
		  unsigned char** varname,
		  unsigned char** varval_def)
		  
{
    int i;  

    strcpy( service->serviceType, serviceType );
    strcpy( service->serviceId, serviceId );
    service->variableCount = count;
    service->variableName = varname;
    for(i = 0; i < count ; ++i)
      strcpy(service->variableStrValue[i], varval_def[i]);
EOS

print <<EOS
    return UPNP_E_SUCCESS;
}
EOS



print <<EOS
static int
InitializeServices(void)
{
    action* actions;
EOS

device.serviceList.each { |service|
	  print "    InitializeService(&serviceTable[#{service.get_macro_name}],\n"
	  print "    \"#{service.serviceType}\", \"#{service.serviceId}\",\n"
	  print "    #{service.get_varcount_macro_name},\n"
	  print "    #{service.get_simple_name}_varname,\n"
	  print "    #{service.get_simple_name}_varval_def \n"

	  print "    );\n\n"
	  

# Action の定義
	  print "    actions = serviceTable[#{service.get_macro_name}].actions;\n\n"
	    action_number = 0
	    service.SCPD.actionList.each{ |action|
	      print "    actions[#{action_number}].name = \"#{action.name}\";\n"
#TODO:
	      print "    actions[#{action_number}].action = #{service.get_simple_name}_#{action.name};\n";
	      action_number+=1
	    }
	    if max_action > action_number
	      print "    actions[#{action_number}].name = NULL;\n"	      
	    end
	    print "\n"
	    

}	
	
print <<EOS
	return UPNP_E_SUCCESS;
}
EOS
      
