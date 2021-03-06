clear all
clc
load('FCZ5_COLL_a');
load('FCZ5_COLL_b');
load('FCZ5_COLL_p');
load('FCZ5_COLL_wind');
load('FCZ5_gas');       %   $/therm   12 monthes

% t_start=4345;  %% July 1st
% t_end=4488;
% t_m=7;

t_start=4681;   %% July 15th~21th  summer   7 days
t_end=4848;
t_m=7;

% t_start=1;  %% Jan 1st
% t_end=12;

% t_start=2160;  %% Apr 1st
% t_end=2640;  

a1=ceil(FCZ5_COLL_a(t_start:t_end,1));
wind1=ceil(FCZ5_COLL_wind(t_start:t_end,1));

a=max(zeros(t_end-t_start+1,1),a1-wind1);
b=ceil(FCZ5_COLL_b(t_start:t_end,1));
p=FCZ5_COLL_p(t_start:t_end,1);

%generate price
% SUMMER SEASON - MAY 1 through OCT 31            $/KWh
% 0~8 ........................................... 0.056
% 8~12 .......................................... 0.103
% 12~18 ......................................... 0.232
% 18~21 ......................................... 0.103
% 21~24 ......................................... 0.056

%off-peak  11 hours
%on-peak   6 hours


gas=FCZ5_gas(t_m,1)/29.3;  %  natural gas price  Jan
                         %  1 therm = 29.3 KWh 

[T,temp]=size(a);

L=3000;               % generator capacity 3000 kw       scale up 30 times
yub=7;                % # of generators
Tu=1;
Td=1;
Ru=3000;
Rd=3000;


% according to tecogen datasheet
% installed costs with heat recovery    3000$/kw
% variable maintenance                  0.02$/kwh
% lifetime                              20 year
cm=110;            %   0.02*3000+3000*3000/20/365/24=113.7
co=gas/0.28;           % elec   efficiency 0.28
g=gas/0.8;        % boiler efficiency
e=1.8;           %   cogeneration heat efficiency

beta=1400;        % 5 times full output operational cost ~ 5*(cm+3000*co)  co take mean                       

%only grid
c_GRID=0;
for t=1:T
    c_GRID=c_GRID+a(t,1)*p(t,1)+b(t,1)*g;
end

%offline MILP
Tud=max(Tu,Td);
Y0=zeros(Tud,yub);
U0=zeros(1,yub);

n=13;

cr_BKE=zeros(n,1);
cr_GridBatt=zeros(n,1);
cr_OPT=zeros(n,1);

w=0;  %look-ahead window

for i=1:n
    batt=(i-1)*1000;     % shave the load during on-peak hours
    Ramp_batt=batt/4;
    a_batt=a;
    for day=1:7
        for j=(day-1)*24+1:(day-1)*24+7
            a_batt(j,1)=a(j,1)+batt/11;
        end
        for j=(day-1)*24+12:(day-1)*24+17
            a_batt(j,1)=max(a(j,1)-batt/6,0);
        end
        for j=(day-1)*24+21:(day-1)*24+24
            a_batt(j,1)=a(j,1)+batt/11;
        end
    end
    [ a_L,b_Le,N ]=quantification(a_batt,b,L,e); %% N layers    
    % BKE
    [c_BKE,y_BKE,u_BKE] = BKE_w( a_L,b_Le,N,p,co,cm,g,e,beta,L,yub,Tu,Td,Ru,Rd,w);   
    cr_BKE(i,1)=(c_GRID-c_BKE)/c_GRID*100;
    
    [c_OPT,y_temp,u_temp] = Offline_MILP_battery( a1,b,wind1,p,co,cm,g,e,beta,L,yub,Tu,Td,Ru,Rd,batt,Ramp_batt,Y0,U0,0.005);
    cr_OPT(i,1)=(c_GRID-c_OPT)/c_GRID*100;
    
    c_GridBatt=0;
    for t=1:T
        c_GridBatt=c_GridBatt+a_batt(t,1)*p(t,1)+b(t,1)*g;
    end
    cr_GridBatt(i,1)=(c_GRID-c_GridBatt)/c_GRID*100;
    
    clear y_BKE
    clear u_BKE
    clear a_batt
    clear a_L
    clear b_Le
    clear y_temp
    clear u_temp
end

cr_BKE3=zeros(n,1);
% cr_RHC=zeros(n,1);

w=3;  %look-ahead window

for i=1:n
    batt=(i-1)*1000;     % shave the load during on-peak hours
    a_batt=a;
    for day=1:7
        for j=(day-1)*24+1:(day-1)*24+7
            a_batt(j,1)=a(j,1)+batt/11;
        end
        for j=(day-1)*24+12:(day-1)*24+17
            a_batt(j,1)=max(a(j,1)-batt/6,0);
        end
        for j=(day-1)*24+21:(day-1)*24+24
            a_batt(j,1)=a(j,1)+batt/11;
        end
    end
    [ a_L,b_Le,N ]=quantification(a_batt,b,L,e); %% N layers    
    % BKE
    [c_BKE,y_BKE,u_BKE] = BKE_w( a_L,b_Le,N,p,co,cm,g,e,beta,L,yub,Tu,Td,Ru,Rd,w);

%     % RHC
%     [c_RHC,y_RHC,u_RHC] = RHC_w(a,b,p,co,cm,g,e,beta,L,yub,Tu,Td,Ru,Rd,w);
    
    cr_BKE3(i,1)=(c_GRID-c_BKE)/c_GRID*100;
%     cr_RHC(i,1)=(c_GRID-c_RHC)/c_GRID*100;
    
    clear y_BKE
    clear u_BKE
    clear a_batt
    clear a_L
    clear b_Le
%     clear y_RHC
%     clear u_RHC
end

save R_summer2_battery

