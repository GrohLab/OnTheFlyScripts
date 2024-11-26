% iRNs
expMice = summMice{1}(3);
aux = expMice.PolygonUnfoldAmplIndx([1,5],:,:,cons_mice); 
% cons_mice comes from the iegRNs_AmplitudeIndexPool.m script

% eOPN3
expMice = summMice{4}(2);
aux = expMice.PolygonUnfoldAmplIndx([1,8],:,:,:);
%%
createtiles = @(f,r,c) tiledlayout( f, r, c, ...
    'TileSpacing', 'Compact', 'Padding', 'tight');

vaxOpts = cellstr( ["HorizontalAlignment", "center", ...
    "VerticalAlignment", "baseline", "Rotation"] );
med_AI_pbp = squeeze( median( aux, 2, "omitmissing" ) );
med_AI_all = median( med_AI_pbp, 3, "omitmissing" );
clrMap = [0.15*ones(1,3); 0, 0.51, 1];
Nb = 8;
bodypart_names = ["Stim-whisker mean", "Stim-whisker fan arc", ...
"Nonstim-whisker mean", "Nonstim-whisker fan arc", "Interwhisk arc", ...
"Symmetry", "Nose", "Roller speed"];

iqr_AI = quantile( med_AI_pbp, [1,3]/4, 3 );
iqr_coords = iqr_AI .* reshape(z_axis,1,[],1);

[f, z_axis, poly_coords] = createPolarPlotPolygons( med_AI_pbp );

[pchObj, ax] = plotPolygons( poly_coords, f, 'clrMap', clrMap );

z_rot = exp( 1i*pi/32 ); 
% Dots by the polygon
arrayfun(@(c,z) line( real( poly_coords(:,c) * z)', ...
    imag( poly_coords(:,c) * z )', 'LineStyle', 'none', ...
    'Marker', '.', 'Color', clrMap(c,:), 'MarkerSize', 20 ), ...
    1:2, [z_rot, z_rot'] )
set( gca, 'Box', 'off', 'Color', 'none', "Visible", "off" );
% Lines for IQR
arrayfun(@(x,z) line( squeeze( real( iqr_coords(:,:,x) * z ) )', ...
    squeeze( imag( iqr_coords(:,:,x) * z ) )', 'LineWidth', 2, ...
    'Color', clrMap(x,:) ), 1:2, [z_rot, z_rot'] )
text(ax, 0.25:0.25:1, zeros(1,4), string( ( 1:4 )'/4 ), ...
    "HorizontalAlignment", "left", "VerticalAlignment", "cap" )
title('Population Polygons for MC\rightarrowiRNs' )
legend( findobj( gca, 'Type', 'Patch' ), {'Laser OFF', 'Laser ON'}, ...
    "Location", "best", "Color", "none", "Box", "off" )
p = arrayfun(@(b) signrank( squeeze( med_AI_pbp(1,b,:) ), ...
    squeeze( med_AI_pbp(2,b,:) ) ), 1:8 );
arrayfun(@(v, y) text( real( 1.25*poly_coords(1,v) ), ...
    imag( 1.25*poly_coords(1,v) ), repmat( '\ast', 1, sum( p(v) < ...
    [0.05, 0.01, 0.001] ) ), "HorizontalAlignment", "center", ...
    "Rotation", y, "VerticalAlignment", "baseline"), 1:8, ...
    (180*angle( transp(z_axis) )/pi) - 90 );

arrayfun(@(v,b,y) text( real( z_axis(v) ), ...
    imag( z_axis(v) ), b, vaxOpts{:}, y ), 1:8, bodypart_names, ...
    (180*angle( transp(z_axis) )/pi) - 90 )