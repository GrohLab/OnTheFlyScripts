% crudeSNR
ind = find(VplCfa.Laser_Control_15mW_LR & VplCfa.Mech_Control_15mW_MR...
& VplCfa.Laser_Control_15mW_Counts_Spont > VplCfa.Laser_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_Counts_Spont < VplCfa.Mech_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_vs_Mech_Laser_15mW_Evoked_Response);
SNRup15 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_15mW_LR & VplCfa.Mech_Control_15mW_MR...
& VplCfa.Laser_Control_15mW_Counts_Spont < VplCfa.Laser_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_Counts_Spont < VplCfa.Mech_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_vs_Mech_Laser_15mW_Evoked_Response);
FRup15 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_10mW_LR & VplCfa.Mech_Control_10mW_MR...
& VplCfa.Laser_Control_10mW_Counts_Spont > VplCfa.Laser_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_Counts_Spont < VplCfa.Mech_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_vs_Mech_Laser_10mW_Evoked_Response);
SNRup10 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_10mW_LR & VplCfa.Mech_Control_10mW_MR...
& VplCfa.Laser_Control_10mW_Counts_Spont < VplCfa.Laser_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_Counts_Spont < VplCfa.Mech_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_vs_Mech_Laser_10mW_Evoked_Response);
FRup10 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_5mW_LR & VplCfa.Mech_Control_5mW_MR...
& VplCfa.Laser_Control_5mW_Counts_Spont > VplCfa.Laser_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_Counts_Spont < VplCfa.Mech_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_vs_Mech_Laser_5mW_Evoked_Response);
SNRup5 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_5mW_LR & VplCfa.Mech_Control_5mW_MR...
& VplCfa.Laser_Control_5mW_Counts_Spont < VplCfa.Laser_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_Counts_Spont < VplCfa.Mech_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_vs_Mech_Laser_5mW_Evoked_Response);
FRup5 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_15mW_LR & VplCfa.Mech_Control_15mW_MR...
& VplCfa.Laser_Control_15mW_Counts_Spont < VplCfa.Laser_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_Counts_Spont > VplCfa.Mech_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_vs_Mech_Laser_15mW_Evoked_Response);
SNRdwn15 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_15mW_LR & VplCfa.Mech_Control_15mW_MR...
& VplCfa.Laser_Control_15mW_Counts_Spont > VplCfa.Laser_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_Counts_Spont > VplCfa.Mech_Control_15mW_Counts_Evoked...
& VplCfa.Mech_Control_15mW_vs_Mech_Laser_15mW_Evoked_Response);
FRdwn15 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_10mW_LR & VplCfa.Mech_Control_10mW_MR...
& VplCfa.Laser_Control_10mW_Counts_Spont < VplCfa.Laser_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_Counts_Spont > VplCfa.Mech_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_vs_Mech_Laser_10mW_Evoked_Response);
SNRdwn10 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_10mW_LR & VplCfa.Mech_Control_10mW_MR...
& VplCfa.Laser_Control_10mW_Counts_Spont > VplCfa.Laser_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_Counts_Spont > VplCfa.Mech_Control_10mW_Counts_Evoked...
& VplCfa.Mech_Control_10mW_vs_Mech_Laser_10mW_Evoked_Response);
FRdwn10 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_5mW_LR & VplCfa.Mech_Control_5mW_MR...
& VplCfa.Laser_Control_5mW_Counts_Spont < VplCfa.Laser_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_Counts_Spont > VplCfa.Mech_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_vs_Mech_Laser_5mW_Evoked_Response);
SNRdwn5 = VplCfa.id(ind);
ind = find(VplCfa.Laser_Control_5mW_LR & VplCfa.Mech_Control_5mW_MR...
& VplCfa.Laser_Control_5mW_Counts_Spont > VplCfa.Laser_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_Counts_Spont > VplCfa.Mech_Control_5mW_Counts_Evoked...
& VplCfa.Mech_Control_5mW_vs_Mech_Laser_5mW_Evoked_Response);
FRdwn5 = VplCfa.id(ind);