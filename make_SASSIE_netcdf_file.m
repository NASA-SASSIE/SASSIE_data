%
%
%
% make_SASSIE_netcdf_file.m
%
%
% This code can be modified to creates a CF-compliant netCDF-4 file for a
% given SASSIE dataset. It reads in the attributes file (SASSIE_attributes.xlsx *** make sure
% the latest version of this file is in the local directory ***) and adds
% the correct attributes for the dataset. The user must customize the
% variable names, units, comments, etc. -- this code is more of a guide
% than a one-size-fits-all script!
%
% k.drushka /// jan 2023
%


% filename:
%
% SASSIE_Fall_2022<_shipboard><_platform/instrument><_XXX><.ext>
%  <_shipboard> is added for instruments operated from the R/V. For other platforms it is omitted.
%  <platform/instrument> = "JetSSP", "UpTempO", "TSG", "SWIFT_aquaDopp" etc.
%  <_XXX> = Optional. Anything else needed to identify the file, like a cast number, date (or date range), glider ID, or instrument serial number. As many characters as needed
%  <.ext> = ".nc" most likely. Use ".nc" not ".nc4".

savename='SASSIE_Fall_2022_XXX.nc'; % replace XXX 
% remove any existing file with this name
if exist(savename,'file')
    eval(['!rm ' savename])
end
% create new file
fprintf(1,' - saving netcdf file %s\n',savename)
nc = netcdf.create(savename,'netcdf4');









% ------ define all dimensions, variables, attributes ------
%  this example assumes the data is in a structure called "data" with
% fields time, depth, lon, lat, T, and S. 

% convert time to days since 1950 and store in a new field, t1950:
data.t1950=data.time-datenum(1950,1,1);

% original variable names (in the "data" structure):
vblnames_orig={'t1950','depth','lon','lat','T','S'};
% new variable names for the NC file (don't have to be CF compliant):
vblnames={'time','depth','longitude','latitude','temperature','salinity'};
% CF compliant variable names for attribute standard_name
vblstdnames={'time','depth','longitude','latitude','sea_water_temperature','sea_water_practical_salinity'};
% long (descriptive) names to store in the "attributes" field:
vbllongnames={'time','depth','longitude','latitude','sea_water_temperature','sea_water_practical_salinity'};

% --- variable-level attributes:
% units - see https://cfconventions.org/Data/cf-standard-names/current/build/cf-standard-name-table.html
dataunits={'Days since 1950-01-01','m','degree_east','degree_north','degree_C','1'};
% coverage_content_type (coordinate [typically for lat/lon/time/depth] or physicalMeasurement)
coverage_content_types={'coordinate', 'coordinate', 'coordinate', 'coordinate', 'physicalMeasurement', 'physicalMeasurement'};
% valid min and max (for physical measurements only; use [] for coordinates)
valid_mins={[],[],[],[],-2, 2};
valid_maxs={[],[],[],[],30, 42};
% any additional comments, e.g. how a given variable was processed
comments={[],[],[],[],['Temperature measured from XXX instrument'],['Salinity spikes were removed using XXX method.']};                

% --- define dimensions and variable names
% - the main dimensions are time x depth
timedimID=netcdf.defDim(nc,'time',length(data.time));
depdimID=netcdf.defDim(nc,'depth',length(data.depth));
% define time and depth vars:
timeID=netcdf.defVar(nc,'time','double',timedimID);
depID=netcdf.defVar(nc,'depth','double',depdimID);

% run through the variables:
vvs=1:length(vblnames); 
for vv=vvs
    % --- define the variable ID
    if strmatch(vblnames{vv},'time')
        % time is a dimension, not a variable - so use "timeID"
        dataID(vv)=timeID;
        % and set the "axis" attribute:
        netcdf.putAtt(nc,dataID(vv),'axis','T');
    elseif strmatch(vblnames{vv},'depth')
        % same for depth
        dataID(vv)=depID;
        % and set the "axis" attribute:
        netcdf.putAtt(nc,dataID(vv),'axis','Z');
    else
        % define variable name using "vblname"
        % - check if 1d or 2d
        if isvector(data.(vblnames_orig{vv}))
            % 1-d vars only have dimension time:
            dataID(vv)=netcdf.defVar(nc,vblnames{vv},'double',timedimID);
        else
            % 2-d vars have dimensions time and depth:
            dataID(vv)=netcdf.defVar(nc,vblnames{vv},'double',[timedimID depdimID]);
        end
        % if lat or lon, set the "axis" attribute:
        if strmatch(vblnames{vv},'lon')
            netcdf.putAtt(nc,dataID(vv),'axis','X');
        elseif strmatch(vblnames{vv},'lat')
            netcdf.putAtt(nc,dataID(vv),'axis','Y');
        end
    end

    % --- add attributes
    netcdf.putAtt(nc,dataID(vv),'units',dataunits{vv});
    netcdf.putAtt(nc,dataID(vv),'standard_name',vblstdnames{vv});
    netcdf.putAtt(nc,dataID(vv),'long_name',vbllongnames{vv});
    netcdf.putAtt(nc,dataID(vv),'coverage_content_type',coverage_content_types{vv});
    % some attribues for physical meausrements only:
    if strmatch(coverage_content_types{vv},'physicalMeasurement')
        fillvalue=-9999;  % preferred fill value is -9999
        netcdf.putAtt(nc,dataID(vv),'_FillValue',fillvalue);
        netcdf.putAtt(nc,dataID(vv),'valid_min',valid_mins{vv});
        netcdf.putAtt(nc,dataID(vv),'valid_max',valid_maxs{vv});
        % "coordinates"  is a "list of variables that can describe the measurement's location in space and time, delimited by spaces (eg: time latitude longitude depth)".
        if isvector(data.(vblnames_orig{vv}))
            % vector data: assume not a function of depth
            netcdf.putAtt(nc,dataID(vv),'coordinates','time latitude longitude');
            
        else
            % 2-d data: assume a function of depth
            netcdf.putAtt(nc,dataID(vv),'coordinates','time latitude longitude depth');            
        end
    end
    % add comment field, if availale for this variable:
    if ~isempty(comments{vv})
        netcdf.putAtt(nc,dataID(vv),'comment',comments{vv});
    end

end
netcdf.endDef(nc);
% exiting netcdf define mode
% --------------


% --- write data
for vv=vvs
    % replace nans with fillvalue
    thisdata = data.(vblnames_orig{vv});
    thisdata(isnan(thisdata))=fillvalue;
    % assign to dataID of this variable 
    netcdf.putVar(nc,dataID(vv),thisdata);
end
% close the file before writing global attributes
netcdf.close(nc);


%  ---- add global attributes - read them from the attributes file (assumed
%  to be in the local directory)
attrfile=('SASSIE_attributes.xlsx');
[ndata, text, alldata] = xlsread(attrfile);

% first row of the file gives all attribute names:
attr_names = {text{1,:}};
% specify which row of the attribute file  corresoponds to the dataset we're creating-  e.g. TSG data is row 17
ATTRIBUTES_FILE_ROW = 17; % replace with the correct row number
attrs={text{ATTRIBUTES_FILE_ROW,:}};

% replace highlighted fields in the spreadsheet:
% ** note, these are for the TSG dataset  - replace these with specifics
% for your own dataset **
% - title:  In the space marked by <XXXX>, insert optional information
% (e.g., Glider ID, cast number) 
ai=strmatch('title',attr_names);
attrs{ai}=['SASSIE Arctic Field Campaign Shipboard Thermosalinograph Data Fall 2022'];

% - summary: This should be a brief description of the type of data
% contained in the file, as well as when and where it was collected – something like an abstract. 
ai=strmatch('summary',attr_names);
attrs{ai}='Shipboard thermosalinograph (TSG) data collected continuously from R/V Woldstad during the 2022 SASSIE field campaign.';

% - comment: add any brief comments relative to the data set. Otherwise skip.
% Variable-specific comments can be entered in the "comments" field above.
ai=strmatch('comment',attr_names);
attrs{ai}=['The Seabird thermosalinograph (TSG) system consisted of a SBE21 SeaCAT TSG, a SBE38 temperature sensor, and a debubbler. Data were logged every minute using SeaSave software and included GPS positions data. A persistent offset of XXX seconds was observed in the TSG salinity data relative to all four sensors on the JetSSP instrument; the TSG data in this file have been corrected for this offset.'];

% - history: This attribute is meant to “provide an audit trail for
% modifications to the original data”.  Add any history relative to the
% data set. If there is no current history, i.e. this is the first version
% of the data, enter ‘none' 
ai=strmatch('history',attr_names);
attrs{ai}='none';

% - product_version: should be 1.0 for the first version
ai=strmatch('product_version',attr_names);
attrs{ai}='1.0';

% - add citations or DOIs here for the papers related to this data set. If
% there is nothing appropriate, this attribute can be skipped.  
ai=strmatch('references',attr_names);
attrs{ai}='none';

% - acknowledgement: add any extra acknowledgement related to the data set.  
ai=strmatch('acknowledgement',attr_names);
attrs{ai}='SASSIE was funded by NASA under grant #80NSSC21K0832.';

% date_created: the date that the data file was originally created in the
% format 'yyyy-mm-ddThh:mm:ssZ' 
ai=strmatch('date_created',attr_names);
attrs{ai}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ');

% date_modified- the date that the data in the file was last modified in
% the format 'yyyy-mm-ddThh:mm:ssZ '
ai=strmatch('date_modified',attr_names);
attrs{ai}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ');

% geospatial_lat_min/max - the lowest/highest latitude covered by the data
% set in units of degrees north of the equator 
ai=strmatch('geospatial_lat_min',attr_names);
attrs{ai}=min(data.lat);
ai=strmatch('geospatial_lat_max',attr_names);
attrs{ai}=max(data.lat);

% geospatial_lon_min/max - the lowest/highest longitude covered by the data
% set in units of degrees_east of the prime meridian. 
ai=strmatch('geospatial_lon_min',attr_names);
attrs{ai}=min(data.lon);
ai=strmatch('geospatial_lon_max',attr_names);
attrs{ai}=max(data.lon);

% time_coverage_start/end – the start and end dates and times of the data
% in the file in the format ‘yyyy-mm-ddThh:mm:ssZ’ 
ai=strmatch('time_coverage_start',attr_names);
attrs{ai}=datestr(min(data.time),'yyyy-mm-ddTHH:MM:SSZ');
ai=strmatch('time_coverage_end',attr_names);
attrs{ai}=datestr(max(data.time),'yyyy-mm-ddTHH:MM:SSZ');

% -- add any attributes that are not part of the spreadsheet:

% uuid- A unique identifier for each netCDF file
uuid=char(java.util.UUID.randomUUID);
attr_names{end+1}='uuid';
attrs{end+1}=uuid;

% time coverage duration -  the end time minus the start
% time of the coverage in the data set. E.g.
% "P12DT12H12M12S" for 12 days, 12 hours, 12 minutes and 12 seconds. 
% See https://en.wikipedia.org/wiki/ISO_8601#Durations
% % Date and time elements including their designator may be omitted if
% their value is zero, and lower-order elements may also be omitted for reduced precision. 
dur=max(data.time)-min(data.time);
% (for the TSG dataduration is slightly less than 1 month, so omit the Y and M elements:
time_coverage_duration = ['P' num2str(floor(dur)) 'DT' datestr(dur,'HH') 'H' datestr(dur,'MM') 'M' datestr(dur,'SS') 'S'];
attr_names{end+1}='time_coverage_duration';
attrs{end+1}=time_coverage_duration;

% loop through the attributes and write them to the file:
fileattrib(savename,'+w')
for ai=1:length(attrs)
    ncwriteatt(savename,'/',attr_names{ai},attrs{ai});
end




