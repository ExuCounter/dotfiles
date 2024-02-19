namespace=$1
function connect_to_spot {
 ans = kubectl get pods --namespace $namespace | fzf
 echo $ans
}

alias connect_to_spot=connect_to_spot
