-module(main).
-import(utils, [test/0]).
-import(lists,[member/2,lists/2]).
-compile(export_all).

% Authors : David Baschung and Augustin Martignoni
% Vocabulary :
%   Node/Peer : process in the network
%   Leecher : peer downloading from other peers
%   Seeder : peer uploading to other peers

start() ->
  io:fwrite("~n~n~n--------- PEER-TO-PEER NETWORK INTERFACE SIMULATION -----------~n-- Concurrent & Distributed Computing, Semester Project 2020 --~n----------- Augustin Martignoni & David Baschung --------------~n~n"),
  tracker(init,[]).

tracker(State, Network) -> % Loops to tracks, deploys and manages all the processes in the variable 'Network'. The files can be asked to each process.
  if (State == init) ->
      io:format("Tracker : started (~p), initializing network.~n",[self()]),
      UpdatedNetwork = deployNetwork(self(), customNetwork()),
      io:format("Tracker : Network deployed : ~p~n~n", [UpdatedNetwork]),
      spawn(?MODULE, launchCustomNetworkActivity, [self()]);
    true ->
      receive
        {getCurrentNetwork, Process} ->
          UpdatedNetwork = Network,
          Process ! {currentNetwork, UpdatedNetwork};
        {printCurrentNetwork} ->
          UpdatedNetwork = Network,
          io:format("Tracker : Current network : ~p~n", [Network])
      end
  end,
  tracker(continue, UpdatedNetwork).

customNetwork() ->
  MyNeighboursIDAndCostMap = [[{2,3},{5,8}],[{1,3},{3,7},{6,5}],[{2,7}],[{5,4},{9,2}],[{1,8},{4,4},{8,3},{9,1},{10,2}],[{2,5},{7,1},{8,3}],[{6,1},{10,2}],[{5,3},{6,3}],[{4,2},{5,1}],[{5,2},{7,2}]], %Lists of {Neighbours and their cost} for each Node to create.
  MyFileNamesMap = [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]],
  {MyNeighboursIDAndCostMap, MyFileNamesMap}.

deployNetwork(Tracker, {NeighboursIDAndCostMap, FileNamesMap} ) -> % Inits the deployment of the initial network.
  io:format("DeployNetwork : deploying the ~b nodes in the initial network.~n", [length(NeighboursIDAndCostMap)]),
  deployNode(Tracker, length(NeighboursIDAndCostMap), {NeighboursIDAndCostMap, FileNamesMap}, [] ).

deployNode(Tracker, N, {[HNeigh|TNeigh], [HFileNames|TFileNames]} , Network) -> % Deploys a node during the initial network deployment.
  UpdatedNetwork = addNodeToNetwork(Tracker, {length(Network)+1, HNeigh, HFileNames, HFileNames}, Network), % We simulate a real File but use the filename for simplification.
  if
    (length(UpdatedNetwork)<N) -> deployNode(Tracker, N, {TNeigh, TFileNames}, UpdatedNetwork);
    true ->
      UpdatedNetwork
  end.

addNodeToNetwork(Tracker, {ID, NeighboursIDAndCost, FileNames, Files}, Network) -> % New node (on network initialization or later)
  ThisNode = spawn(?MODULE, action, [Tracker, {ID, NeighboursIDAndCost, Files}]),
  UpdatedNetwork = Network ++ [{ID,ThisNode,FileNames}],
  io:format("AddNodeToNetwork : Node ~b (process ~p) initialized :~n{Neighbour and Cost} list : ~p, Files : ~p.~n",[ID,ThisNode,NeighboursIDAndCost,FileNames]),
  UpdatedNetwork.
  








action(Tracker, {ID, NeighboursIDAndCost, Files}) -> % Loops for every possible action on a deployed Node.
  receive
    
    {declareFiles, Process} -> % Lists all the files possessed by the current Node, to the Client
      Process ! {files, Files},
      NewFiles = Files;
    {addFile, File} -> % Adds a File to the current Node
      NewFiles = Files ++ [File];
    {removeFile, File} -> % Removes a File from the current Node
      NewFiles = Files -- [File];


    {downloadFromMultipleSources, [[NextSeederID|OtherNodes] | OtherPaths], [NextUploadPath|OtherUploadPaths], File} -> % Sends a download file order on several source paths that will upload it into this node.
      Tracker ! {getCurrentNetwork, self()},
      receive
        {currentNetwork, CurrentNetwork} -> CurrentNetwork
      end,
      [NextSeeder ! {download, OtherNodes, NextUploadPath, File} || {A,NextSeeder,_} <- CurrentNetwork, A==NextSeederID],
      self() ! {downloadFromMultipleSources, OtherPaths, OtherUploadPaths, File},
      NewFiles = Files;
    {downloadFromMultipleSources, [], Files } -> % (End of recursive call)
      NewFiles = Files;
    {download, [NextSeederID|OtherNodesID], UploadPath, File} -> % Send a download file order on only one source path that will upload it into this node.
      io:format("Action : node ~p downloading. File:~p Files:~p~n",[ID,File,Files]),
      io:format("Action : NextSeederID:~p OtherNodes:~p File:~p~n",[NextSeederID,OtherNodesID,File]),
      Tracker ! {getCurrentNetwork, self()},
      receive
        {currentNetwork, CurrentNetwork} -> 0
      end,
      [NextSeeder ! {download, OtherNodesID, UploadPath, File} || {A,NextSeeder,_} <- CurrentNetwork, A==NextSeederID],
      NewFiles = Files;
    {download, [], UploadPath, File} -> % (End of recursive call)
      io:format("Action : Node ~p found the file ~p. Begin uploading~n", [ID,File]),
      self() ! {upload, UploadPath, File},
      NewFiles = Files;
    {upload, [NextLeecherID|OtherNodes], File} -> % Sends a file to a downloader
      io:format("Action : NextLeecherID:~p OtherNodes:~p~n",[NextLeecherID,OtherNodes]),
      Tracker ! {getCurrentNetwork, self()},
      receive
        {currentNetwork, CurrentNetwork} -> CurrentNetwork
      end,
      [NextLeecher ! {upload, OtherNodes, File} || {A,NextLeecher,_} <- CurrentNetwork, A==NextLeecherID],
      NewFiles = Files;
    {upload, [], File} -> % (End of recursive call)
      NewFiles = Files ++ [File],
      io:format("Action : File ~p acquired by Node ~p. Files:~p~n",[File,ID,NewFiles])
      
  end,
  action(Tracker, {ID, NeighboursIDAndCost, NewFiles}).










launchCustomNetworkActivity(Tracker) -> % launches a running demonstration of the network
  io:format("Activity : Launching some custom network activity.~n"),

  Tracker ! {getCurrentNetwork, self()},
  receive {currentNetwork, [{_,Node1,_},{_,Node2,_} | _] } ->
    0
  end,

  Node1 ! {declareFiles, self()},
  receive {files, Files1} ->
    io:format("Activity : node 1 has current files at the beginning : ~p~n",[Files1])
  end,
  Node2 ! {declareFiles, self()},
  receive {files, Files2} ->
    io:format("Activity : node 2 has current files at the beginning : ~p~n",[Files2])
  end,

  io:format("~nActivity : node 1 downloads from node 7 :~n"),
  Node1 ! {download, [1,2,6,7], [7,6,2,1], 7}, % ( NOTE : the source node for download/upload can be included in the path. )
  timer:sleep(500),

  io:format("~nActivity : node 2 downloads file 7 from multiple nodes 1 and 7 :~n"),
  Node2 ! {downloadFromMultipleSources, [[2,6,7],[2,1]], [[7,6,2],[12]], 7},
  timer:sleep(500).


