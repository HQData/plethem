
interactivePBPK <- function(name = ""){
  shiny::runApp(system.file(name,package="plethem"),launch.browser = T)
}
#' Launch HT-IVIVE interface
#' @description Used internally to launch the HT-IVIVE UI. HT-IVIVE does not use the project management system that PBPK models uses.
#' @param name name of the  model. Has to be "HT-IVIVE"
#' @examples
#' \dontrun{
#' interactiveHT("HT-IVIVE")
#' }
#' @export
interactiveHT <- function(name = ""){
  shiny::runApp(system.file(name,package = "plethem"),launch.browser = T)
}

#' Save the current project to a location
#' @description Save the current PBPK or HTIVIVE project the user is working on.
#' This cannot be used to save exposure or IVIVE gadget data.
#' This function should not be called directly from the console. It will be called by the app on exit
#' @export
saveProject <- function(){
  #Get Project details from the database
  project_details <- projectReadTable("Project")
  name <- project_details$name
  base_path <- project_details$path
  complete_file_path <- file.path(base_path,paste0(name,".Rdata"))
  type <- project_details$type
  # get all the table names from the database
  query <- "SELECT name FROM sqlite_master WHERE type = 'table';"
  table_names_list <- projectDbSelect(query)$name
  #print(which(table_names_list == "sqlite_sequence",arr.ind = T))
  table_names_list <- table_names_list[which(table_names_list != "sqlite_sequence",arr.ind = T)]
  for (x in table_names_list){
    assign(x,projectReadTable(x))
  }
  save(list = table_names_list,file = complete_file_path)


}

#' Start a new PLETHEM project.
#' @description A project consists of chemicals, organisms and datasets. The function asks the user for a location to save the project files on exit. It then launches the shiny user interface used to parameterize and run the model.
#' @param name The name for the project
#' @param type The type of the model that the project is tied to
#' @param model The model to be used for the project
#' @param mode Either Forward Dosimetry(FD) or Monte Carlo(MC) mode. Only valid for PBPK type models
#' @examples
#' \dontrun{
#' newProject(name = "TestPBPK",type = "PBPK",model = "rapidPBPK",mode = "MC")
#' newProject(name = "TestPBPK",type = "PBPK",mode = "httk_pbpk",mode = "MC")
#' }
#' @export
newProject <- function(name="new_project", type = "PBPK", model = "rapidPBPK", mode = "MC"){
  temp_path <- tcltk::tk_choose.dir(caption =sprintf("Select folder where %s will be saved",name))
  
  save_path <- gsub("\\\\","/",temp_path)
  clearProjectDb()
  # write new project details to the project table
  query <- sprintf("INSERT INTO Project (name, path, type, model, mode) Values ('%s','%s','%s','%s','%s');",
                   name,save_path,type,model,mode)
  projectDbUpdate(query)
  # run the appropriate UI
  if (type == "PBPK" && model == "rapidPBPK" && mode == "FD"){
    shiny::runApp(system.file("rapidPBPK",package="plethem"),launch.browser = T)
  }
  if (type == "PBPK" && model == "rapidPBPK" && mode == "MC"){
    shiny::runApp(system.file("rapidPBPK_pop",package="plethem"),launch.browser = T)
  }
  if(type=="PBPK"&& model == "httk_pbtk" && mode == "MC"){
    shiny::runApp(system.file("httk_pbtk",package="plethem"),launch.browser = T)
  }
  #interactivePBPK(model)
  return(NULL)
}


#' Load the project from the project file located at the given path
#' @description Loads the project data from the project file and then launches the shiny UI that corresponds to the analysis type that the project belongs to.
#' @param file_path path to the project file. If no path is provided, launches a select file dialog box for the user to select the path
#' @examples 
#' \dontrun{
#' loadProject(file_path = "C:/Project/TestPBPK.Rdata")
#' loadProject()
#' }

#' @export
loadProject <- function(file_path = ""){
  if(file_path == ""){
    file_path <- tcltk::tk_choose.files(caption = "Select PLETHEM Project",
                                          filter= matrix(c("*.Rdata"),4,2,byrow=TRUE))
    
  }
  
  load(file_path)
  # set the project details to match where the current file was loaded from
  # this will be helpful if the user changes the location/name of the files outside the package
  Project$name <- gsub(".Rdata","",basename(file_path))
  Project$path <- dirname(file_path)
  type <- Project$type
  model <- Project$model
  mode <- Project$mode
  # get all the table names from the database
  query <- "SELECT name FROM sqlite_master WHERE type = 'table';"
  table_names_list <- projectDbSelect(query)$name
  table_names_list <- table_names_list[which(table_names_list != "sqlite_sequence",arr.ind = T)]
  # can use apply here but tables are small and for is more readable
  for (x in table_names_list){
    projectWriteTable(eval(parse(text = x)),x)
  }
  if (type == "PBPK" && model == "rapidPBPK" && mode == "FD"){
    shiny::runApp(system.file("rapidPBPK",package="plethem"),launch.browser = T)
  }
  if (type == "PBPK" && model == "rapidPBPK" && mode == "MC"){
    
    shiny::runApp(system.file("rapidPBPK_pop",package="plethem"),launch.browser = T)
  }
  if(type=="PBPK"&& model == "httk_pbtk" && mode == "MC"){
    shiny::runApp(system.file("httk_pbtk",package="plethem"),launch.browser = T)
  }
}


#' Clear Project Db
#' @description This function clears the project Db. It is called internally when a new project is created. 
#' It is also used by developers to make a clean project db
#' 
clearProjectDb <- function(){
  query <- "SELECT name FROM sqlite_master WHERE type = 'table';"
  table_names_list <- projectDbSelect(query)$name
  table_names_list <- table_names_list[which(table_names_list != "sqlite_sequence",arr.ind = T)]
  # can use apply here but tables are small and for is more readable
  for (x in table_names_list){
    projectDbUpdate(sprintf("DELETE FROM %s ;",x))
  }
}